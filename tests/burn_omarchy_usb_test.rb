require 'digest'
require 'fileutils'
require 'open3'
require 'tmpdir'

SCRIPT = File.expand_path('../scripts/burn-omarchy-usb.sh', __dir__)
X86_ISO = 'omarchy-4.5.0-x86.iso'.freeze
ARM_ISO = 'omarchy-4.5.0-aarch64.iso'.freeze
SITE_HTML = <<~HTML.freeze
  <a href="https://iso.omarchy.org/#{X86_ISO}">x86</a>
  <a href="https://iso.omarchy.org/#{X86_ISO}.sig">signature</a>
  <a href="https://iso.omarchy.org/#{ARM_ISO}">ARM</a>
HTML
USB_DRIVE = 'NAME="/dev/fakeusb" TYPE="disk" RM="1" TRAN="usb" SIZE="57.9G" MODEL="Fake Stick" SERIAL="A1"'.freeze
INTERNAL_DRIVES = <<~LIST.freeze
  NAME="/dev/fakenvme" TYPE="disk" RM="0" TRAN="nvme" SIZE="1.8T" MODEL="Fake SSD"
  NAME="/dev/fakefixedusb" TYPE="disk" RM="0" TRAN="usb" SIZE="1T" MODEL="Fake Disk"
  NAME="/dev/fakesd" TYPE="disk" RM="1" TRAN="mmc" SIZE="32G" MODEL="Fake Card"
  NAME="/dev/fakerom" TYPE="rom" RM="1" TRAN="usb" SIZE="4G" MODEL="Fake Disc"
LIST
# The external commands that reach the network or a drive are fakes. The fake
# sudo runs only the script's root shell, and that shell finds a fake dd first,
# so these tests cannot change a real drive.
FAKE_COMMANDS = {
  'curl' => <<~'BASH',
    #!/bin/bash
    echo "curl $*" >> "$FAKE_ROOT/log"
    output=''
    url=''
    while (( $# > 0 )); do
      case "$1" in
        -o) output=$2; shift ;;
        http*) url=$1 ;;
      esac
      shift
    done
    source_file="$FAKE_ROOT/web/${url##*/}"
    [[ $url == https://omarchy.org/ ]] && source_file="$FAKE_ROOT/web/index.html"
    if [[ ! -f $source_file ]]; then
      if [[ -n $output ]]; then printf 'partial' > "$output"; fi
      exit 22
    fi
    if [[ -n $output ]]; then cp "$source_file" "$output"; else cat "$source_file"; fi
  BASH
  'lsblk' => <<~'BASH',
    #!/bin/bash
    case "$1" in
      -Pdpo)
        columns() { if [[ $1 == *SERIAL* ]]; then cat; else sed 's/ SERIAL="[^"]*"//'; fi; }
        if [[ -n ${3:-} ]]; then
          line=$(grep -F "NAME=\"$3\"" "$FAKE_ROOT/drives") || exit 32
          columns "$2" <<< "$line"
          exit 0
        fi
        columns "$2" < "$FAKE_ROOT/drives"
        if [[ -f $FAKE_ROOT/drives-after-scan ]]; then mv "$FAKE_ROOT/drives-after-scan" "$FAKE_ROOT/drives"; fi
        ;;
      -bdno) cat "$FAKE_ROOT/drive-size" ;;
      -no) if [[ -f $FAKE_ROOT/old-lsblk ]]; then exit 1; fi ;;
      -nlo)
        [[ $2 == LABEL ]] && printf 'OLD_LABEL\nOLD_LABEL\n\n'
        if [[ $2 == MOUNTPOINTS ]]; then
          if [[ -f $FAKE_ROOT/lsblk-mounts-fail ]]; then exit 1; fi
          cat "$FAKE_ROOT/mountpoints"
        fi
        ;;
      *) exit 99 ;;
    esac
  BASH
  'sudo' => <<~'BASH'
    #!/bin/bash
    echo "sudo $1${2:+ $2}" >> "$FAKE_ROOT/log"
    case "$1" in
      -v)
        if [[ -f $FAKE_ROOT/drives-after-auth ]]; then mv "$FAKE_ROOT/drives-after-auth" "$FAKE_ROOT/drives"; fi
        exit "$(cat "$FAKE_ROOT/auth-status")"
        ;;
      umount)
        status=$(cat "$FAKE_ROOT/umount-status")
        if (( status == 0 )) && [[ ! -f $FAKE_ROOT/sticky-mounts ]]; then
          grep -vFx -- "$2" "$FAKE_ROOT/mountpoints" > "$FAKE_ROOT/mountpoints.new" || true
          mv "$FAKE_ROOT/mountpoints.new" "$FAKE_ROOT/mountpoints"
        fi
        exit "$status"
        ;;
      bash)
        shift
        if [[ -f $FAKE_ROOT/root-shell-fails ]]; then exit 1; fi
        PATH="$FAKE_ROOT/root-bin:$PATH" exec /bin/bash "$@"
        ;;
      *) exit 99 ;;
    esac
  BASH
}.freeze
ROOT_DD = <<~'BASH'.freeze
  #!/bin/bash
  echo "root dd $*" >> "$FAKE_ROOT/log"
  case "$1" in
    if=/dev/*)
      status=$(cat "$FAKE_ROOT/read-status")
      if (( status != 0 )); then exit "$status"; fi
      cat "$FAKE_ROOT/written"
      if [[ -f $FAKE_ROOT/corrupt-read-back ]]; then printf 'corrupt'; fi
      ;;
    if=*)
      status=$(cat "$FAKE_ROOT/dd-status")
      if (( status == 0 )); then cp "${1#if=}" "$FAKE_ROOT/written"; fi
      exit "$status"
      ;;
    *) exit 99 ;;
  esac
BASH
$checks = 0
$failures = 0

def assert(condition, message = 'assertion failed')
  raise message unless condition
end

def iso_content(label = 'OMARCHY_202611')
  content = "\0".b * 40_000
  content[32_769, 5] = 'CD001'
  content[32_808, 32] = label.ljust(32)
  content
end

def fixture
  Dir.mktmpdir('burn-omarchy-usb-test-') do |root|
    bin = "#{root}/bin"
    web = "#{root}/web"
    FileUtils.mkdir_p([bin, web, "#{root}/home", "#{root}/root-bin"])
    File.write("#{root}/root-bin/dd", ROOT_DD)
    File.chmod(0o755, "#{root}/root-bin/dd")
    FAKE_COMMANDS.each do |name, content|
      File.write("#{bin}/#{name}", content)
      File.chmod(0o755, "#{bin}/#{name}")
    end
    File.write("#{web}/index.html", SITE_HTML)
    [X86_ISO, ARM_ISO].each do |name|
      File.binwrite("#{web}/#{name}", iso_content)
      File.write("#{web}/#{name}.sha256", "#{Digest::SHA256.hexdigest(iso_content)}  #{name}\n")
    end
    File.write("#{root}/drives", "#{INTERNAL_DRIVES}#{USB_DRIVE}\n")
    File.write("#{root}/drive-size", "1000000\n")
    File.write("#{root}/mountpoints", "/run/media/user/OLD_LABEL\n\n")
    %w[auth umount dd read].each { |name| File.write("#{root}/#{name}-status", "0\n") }
    File.write("#{root}/log", '')
    yield root
  end
end

def run_script(root, input, path: "#{root}/bin:#{ENV.fetch('PATH')}")
  env = { 'FAKE_ROOT' => root, 'HOME' => "#{root}/home", 'PATH' => path }
  Open3.capture2e(env, '/bin/bash', SCRIPT, stdin_data: input)
end

def log(root)
  File.readlines("#{root}/log", chomp: true)
end

def sudo_calls(root)
  log(root).select { |line| line.start_with?('sudo ') }
end

def write_calls(root)
  log(root).select { |line| line.start_with?('root dd ') }
end

def downloaded(root, name)
  "#{root}/home/Downloads/#{name}"
end

def check(name)
  fixture { |root| yield root }
  $checks += 1
  puts "PASS #{name}"
rescue StandardError => error
  $failures += 1
  warn "FAIL #{name}: #{error.message}\n#{error.backtrace.first(3).join("\n")}"
end

check('the latest x86 ISO is the default and is written after confirmation') do |root|
  output, status = run_script(root, "\n\n1\nfakeusb\n")
  assert status.success?, output
  assert File.exist?(downloaded(root, X86_ISO)), 'the ISO was not kept in Downloads'
  assert !File.exist?(downloaded(root, "#{X86_ISO}.part")), 'the partial file was left behind'
  iso = downloaded(root, X86_ISO)
  expected = ['sudo -v', 'sudo umount /run/media/user/OLD_LABEL', 'sudo bash -c',
              "root dd if=#{iso} of=/dev/fakeusb bs=4M conv=fsync,nocreat oflag=direct status=progress",
              'root dd if=/dev/fakeusb bs=4M iflag=count_bytes count=40000 status=progress']
  actual = log(root).reject { |line| line.start_with?('curl ') }
  assert actual == expected, actual.inspect
  assert output.include?('Latest from omarchy.org (4.5.0)'), output
  assert output.include?('Omarchy 4.5.0'), output
  assert output.include?('OMARCHY_202611'), output
  assert output.include?('Drive:    /dev/fakeusb  57.9G  Fake Stick  OLD_LABEL'), output
  assert output.include?('Everything on this drive will be erased.'), output
  assert output.include?('Writing 40000 bytes (0.0 GB)'), output
  assert output.include?('Checking the 40000 bytes (0.0 GB) that were written'), output
  assert File.binread("#{root}/written") == iso_content, 'the ISO was not written'
end

check('the ARM ISO can be chosen') do |root|
  output, status = run_script(root, "1\n2\n1\nfakeusb\n")
  assert status.success?, output
  assert File.exist?(downloaded(root, ARM_ISO)), output
  assert !File.exist?(downloaded(root, X86_ISO)), output
end

check('only removable USB drives are offered') do |root|
  output, status = run_script(root, "1\n1\n3\n3\n3\n")
  assert !status.success?, output
  assert output.include?('/dev/fakeusb  57.9G  Fake Stick  OLD_LABEL'), output
  %w[fakenvme fakefixedusb fakesd fakerom].each do |drive|
    assert !output.include?(drive), "#{drive} was offered"
  end
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('a drive inserted later is found by scanning again') do |root|
  File.write("#{root}/drives", INTERNAL_DRIVES)
  File.write("#{root}/drives-after-scan", "#{USB_DRIVE}\n")
  output, status = run_script(root, "1\n1\n1\n1\nfakeusb\n")
  assert status.success?, output
  assert output.include?('No removable USB drives found.'), output
  assert output.include?('/dev/fakeusb  57.9G  Fake Stick  OLD_LABEL'), output
end

check('canceling at the drive menu writes nothing') do |root|
  File.write("#{root}/drives", INTERNAL_DRIVES)
  output, status = run_script(root, "1\n1\n2\n")
  assert !status.success?, output
  assert output.include?('Nothing was written.'), output
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('a download with the wrong checksum stops before any drive step') do |root|
  File.write("#{root}/web/#{X86_ISO}.sha256", "#{'0' * 64}  #{X86_ISO}\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('does not match the published checksum'), output
  assert !File.exist?(downloaded(root, X86_ISO)), 'the bad ISO was kept'
  assert !File.exist?(downloaded(root, "#{X86_ISO}.part")), 'the bad partial file was kept'
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('a missing published checksum stops before downloading') do |root|
  FileUtils.rm("#{root}/web/#{X86_ISO}.sha256")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('Could not get the published checksum'), output
  assert log(root).none? { |line| line.end_with?("/#{X86_ISO}") }, log(root).inspect
end

check('an ISO already downloaded is verified and not downloaded again') do |root|
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.binwrite(downloaded(root, X86_ISO), iso_content)
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert status.success?, output
  assert output.include?("Found #{downloaded(root, X86_ISO)}"), output
  assert log(root).none? { |line| line.end_with?("/#{X86_ISO}") }, log(root).inspect
end

check('an existing ISO with the wrong checksum is kept and stops the run') do |root|
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.binwrite(downloaded(root, X86_ISO), iso_content('DIFFERENT'))
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert File.exist?(downloaded(root, X86_ISO)), 'the existing file was deleted'
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('a wrong device name cancels without touching the drive') do |root|
  output, status = run_script(root, "1\n1\n1\nsda\n")
  assert !status.success?, output
  assert output.include?('Nothing was written.'), output
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('the end of input cancels at the confirmation') do |root|
  output, status = run_script(root, "1\n1\n1\n")
  assert !status.success?, output
  assert output.include?('Nothing was written.'), output
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('an invalid menu answer is asked again') do |root|
  output, status = run_script(root, "9\nx\n1\n1\n1\nfakeusb\n")
  assert status.success?, output
  assert output.scan('Enter a number from 1 to 2.').length == 2, output
end

check('a local ISO without a published checksum gets a warning and can be written') do |root|
  FileUtils.mkdir_p("#{root}/home/Downloads")
  iso = downloaded(root, 'omarchy-3.8.2.iso')
  File.binwrite(iso, iso_content('OMARCHY_202605'))
  output, status = run_script(root, "2\n1\n1\nfakeusb\n")
  assert status.success?, output
  assert output.include?('it cannot be verified'), output
  assert output.include?('Omarchy 3.8.2'), output
  assert output.include?('OMARCHY_202605'), output
  assert write_calls(root).any? { |line| line.include?("if=#{iso} of=/dev/fakeusb") }, log(root).inspect
end

check('a local ISO is checked when a published checksum exists') do |root|
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.binwrite(downloaded(root, X86_ISO), iso_content('DIFFERENT'))
  output, status = run_script(root, "2\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('does not match the published checksum'), output
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('a local file that is not an ISO is rejected') do |root|
  File.write("#{root}/notes.txt", 'not an image')
  output, status = run_script(root, "2\n1\n#{root}/notes.txt\n")
  assert !status.success?, output
  assert output.include?('is not an ISO image'), output
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('only local ISOs are offered when the website is unavailable') do |root|
  FileUtils.rm("#{root}/web/index.html")
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.binwrite(downloaded(root, 'omarchy-3.8.2.iso'), iso_content('OMARCHY_202605'))
  output, status = run_script(root, "1\n1\nfakeusb\n")
  assert status.success?, output
  assert output.include?('Only ISOs on this computer are available.'), output
  assert !output.include?('Latest from omarchy.org'), output
end

check('only local ISOs are offered when the website lists no ISO') do |root|
  File.write("#{root}/web/index.html", '<p>Redesigned</p>')
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.binwrite(downloaded(root, 'omarchy-3.8.2.iso'), iso_content('OMARCHY_202605'))
  output, status = run_script(root, "1\n1\nfakeusb\n")
  assert status.success?, output
  assert output.include?('Only ISOs on this computer are available.'), output
  assert output.include?('download it from that website'), output
end

check('a missing architecture on the website is reported') do |root|
  File.write("#{root}/web/index.html", "<a href=\"https://iso.omarchy.org/#{X86_ISO}\">x86</a>")
  output, status = run_script(root, "1\n2\n")
  assert !status.success?, output
  assert output.include?('does not list an ISO for aarch64'), output
end

check('an ISO larger than the drive is rejected before confirmation') do |root|
  File.write("#{root}/drive-size", "1000\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('does not fit'), output
  assert sudo_calls(root).empty?, sudo_calls(root).inspect
end

check('a drive that cannot be unmounted is not written') do |root|
  File.write("#{root}/umount-status", "32\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('Could not unmount'), output
  assert write_calls(root).empty?, log(root).inspect
end

check('a drive used as swap is not written') do |root|
  File.write("#{root}/mountpoints", "[SWAP]\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('in use as swap'), output
  assert write_calls(root).empty?, log(root).inspect
end

check('a failed write is reported') do |root|
  File.write("#{root}/dd-status", "1\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('Writing failed'), output
  assert write_calls(root).length == 1, log(root).inspect
  assert !output.include?('Done.'), output
end

check('a failed read-back comparison is reported') do |root|
  File.write("#{root}/corrupt-read-back", '')
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('does not match the ISO'), output
  assert !output.include?('Done.'), output
end

check('a failed read-back is reported as a read failure') do |root|
  File.write("#{root}/read-status", "1\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('Could not read'), output
  assert !output.include?('Done.'), output
end

check('a mismatch that stops the read early is reported as a mismatch') do |root|
  File.write("#{root}/read-status", "141\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('does not match the ISO'), output
  assert !output.include?('Could not read'), output
end

check('a root shell that cannot start is not reported as a mismatch') do |root|
  File.write("#{root}/root-shell-fails", '')
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('may be unchanged or incomplete'), output
  assert !output.include?('does not match'), output
end

check('failed authentication writes nothing') do |root|
  File.write("#{root}/auth-status", "1\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('Could not get administrator rights'), output
  assert write_calls(root).empty?, log(root).inspect
end

check('a drive removed after confirmation is not written') do |root|
  File.write("#{root}/drives-after-auth", INTERNAL_DRIVES)
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('no longer the drive you chose'), output
  assert write_calls(root).empty?, log(root).inspect
  assert sudo_calls(root).none? { |line| line.start_with?('sudo umount') }, log(root).inspect
end

check('another disk taking the device name is not written') do |root|
  File.write("#{root}/drives-after-auth", "#{USB_DRIVE.sub('SERIAL="A1"', 'SERIAL="OTHER"')}\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('no longer the drive you chose'), output
  assert write_calls(root).empty?, log(root).inspect
end

check('every mount of the drive is unmounted') do |root|
  File.write("#{root}/mountpoints", "/run/media/user/A\n\n/mnt/with space\n")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert status.success?, output
  ['sudo umount /run/media/user/A', 'sudo umount /mnt/with space'].each do |line|
    assert sudo_calls(root).include?(line), log(root).inspect
  end
end

check('a drive still mounted after unmounting is not written') do |root|
  File.write("#{root}/sticky-mounts", '')
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('still mounted'), output
  assert write_calls(root).empty?, log(root).inspect
end

check('a failed mount check writes nothing') do |root|
  File.write("#{root}/lsblk-mounts-fail", '')
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('Could not check whether'), output
  assert write_calls(root).empty?, log(root).inspect
end

check('a failed download removes its partial file and stops') do |root|
  FileUtils.rm("#{root}/web/#{X86_ISO}")
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('The download failed'), output
  assert !File.exist?(downloaded(root, "#{X86_ISO}.part")), 'the partial file was left behind'
  assert sudo_calls(root).empty?, log(root).inspect
end

check('a download left over from an interrupted run restarts from the beginning') do |root|
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.write(downloaded(root, "#{X86_ISO}.part"), 'interrupted')
  output, status = run_script(root, "1\n1\n1\nfakeusb\n")
  assert status.success?, output
  assert File.binread(downloaded(root, X86_ISO)) == iso_content, 'the ISO was not downloaded in full'
  assert log(root).none? { |line| line.include?(' -C ') }, log(root).inspect
end

check('a local ISO is still checked when the website is unavailable') do |root|
  FileUtils.rm("#{root}/web/index.html")
  FileUtils.mkdir_p("#{root}/home/Downloads")
  File.binwrite(downloaded(root, X86_ISO), iso_content('DIFFERENT'))
  output, status = run_script(root, "1\n1\nfakeusb\n")
  assert !status.success?, output
  assert output.include?('does not match the published checksum'), output
  assert sudo_calls(root).empty?, log(root).inspect
end

check('an lsblk too old for the mount check stops before any choice') do |root|
  File.write("#{root}/old-lsblk", '')
  output, status = run_script(root, '')
  assert !status.success?, output
  assert output.include?('This lsblk is too old'), output
  assert log(root).empty?, log(root).inspect
end

check('missing tools are named before anything happens') do |root|
  empty = "#{root}/empty"
  FileUtils.mkdir_p(empty)
  output, status = run_script(root, '', path: empty)
  assert !status.success?, output
  assert output.include?('Install these tools and run again: cmp curl dd'), output
  assert log(root).empty?, log(root).inspect
end

puts "#{$checks} checks passed"
if $failures.positive?
  warn "#{$failures} checks failed"
  exit 1
end
