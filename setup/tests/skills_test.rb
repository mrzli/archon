require 'tmpdir'
require 'pathname'
require_relative '../setup'

def assert(condition, message = 'assertion failed')
  raise message unless condition
end

def assert_refused(message)
  yield
  raise 'expected refusal'
rescue RuntimeError => error
  raise unless error.message.include?(message)
end

Dir.mktmpdir('archon-skills-') do |root|
  home = "#{root}/home with spaces"
  source = "#{home}/custom data/archon-skills/skills"
  destinations = %w[.agents .claude].map { |name| "#{home}/#{name}/skills" }
  FileUtils.mkdir_p(["#{source}/productivity/first/references", "#{source}/productivity/second", *destinations])
  File.write("#{source}/productivity/first/SKILL.md", 'first skill')
  File.write("#{source}/productivity/first/references/old.md", 'old reference')
  File.write("#{source}/productivity/second/SKILL.md", 'second skill')
  FileUtils.mkdir_p(["#{source}/development/third/scripts", "#{source}/experimental/first",
                     "#{source}/experimental/ignored", "#{source}/productivity/not-a-skill"])
  File.write("#{source}/development/third/SKILL.md", 'third skill')
  File.write("#{source}/development/third/scripts/run.sh", 'echo third')
  File.write("#{source}/experimental/first/SKILL.md", 'ignored duplicate')
  File.write("#{source}/experimental/ignored/SKILL.md", 'ignored skill')
  FileUtils.mkdir_p("#{home}/.codex/skills/.system")
  File.write("#{home}/.codex/skills/.system/keep", 'system skill')

  destinations.each do |directory|
    FileUtils.mkdir_p("#{directory}/personal")
    File.write("#{directory}/personal/SKILL.md", 'personal skill')
    File.symlink('/usr/share/omarchy/default/agents/skills/omarchy', "#{directory}/omarchy")
    File.symlink("#{root}/unrelated-missing", "#{directory}/unrelated")
    File.symlink("#{File.dirname(source)}-other/missing", "#{directory}/similar-prefix")
    File.symlink("#{File.dirname(source)}/.agents/skills/first", "#{directory}/first")
    File.symlink("#{File.dirname(source)}/.agents/skills/removed", "#{directory}/removed")
    File.symlink("#{source}/experimental/ignored", "#{directory}/ignored")
  end

  2.times { sync_user_skill_links(source, home) }
  destinations.each do |directory|
    %w[first second].each do |name|
      assert File.readlink("#{directory}/#{name}") == "#{source}/productivity/#{name}"
      assert File.read("#{directory}/#{name}/SKILL.md") == "#{name} skill"
    end
    assert File.readlink("#{directory}/third") == "#{source}/development/third"
    assert File.read("#{directory}/third/scripts/run.sh") == 'echo third'
    %w[experimental productivity development ignored removed not-a-skill].each do |name|
      assert !path_exists?("#{directory}/#{name}")
    end
  end

  # Duplicate names across included groups fail before any links are changed.
  FileUtils.mkdir_p("#{source}/development/first")
  File.write("#{source}/development/first/SKILL.md", 'duplicate skill')
  assert_refused('Duplicate skill name: first') { sync_user_skill_links(source, home) }
  destinations.each do |directory|
    assert File.readlink("#{directory}/first") == "#{source}/productivity/first"
  end
  FileUtils.rm_r("#{source}/development/first")

  # File changes are immediately visible; renames need link reconciliation.
  File.write("#{source}/productivity/first/SKILL.md", 'updated first skill')
  File.unlink("#{source}/productivity/first/references/old.md")
  FileUtils.mv("#{source}/productivity/second", "#{source}/productivity/renamed")
  FileUtils.mv("#{source}/development/third", "#{source}/productivity/third")
  destinations.each do |directory|
    File.symlink("#{source}/already-deleted", "#{directory}/already-deleted")
    relative = Pathname.new("#{source}/relative-deleted").relative_path_from(Pathname.new(directory)).to_s
    File.symlink(relative, "#{directory}/relative-deleted")
    File.unlink("#{directory}/first")
    File.symlink("#{source}/wrong-target", "#{directory}/first")
  end
  sync_user_skill_links(source, home)
  assert File.read("#{destinations.first}/first/SKILL.md") == 'updated first skill'
  assert !File.exist?("#{destinations.first}/first/references/old.md")
  destinations.each do |directory|
    assert File.readlink("#{directory}/first") == "#{source}/productivity/first"
    assert File.readlink("#{directory}/renamed") == "#{source}/productivity/renamed"
    assert File.readlink("#{directory}/third") == "#{source}/productivity/third"
    %w[second already-deleted relative-deleted].each { |name| assert !path_exists?("#{directory}/#{name}") }
  end

  # Missing source is an error, while an existing empty source removes all managed links.
  assert_refused('Missing skills source') { sync_user_skill_links("#{source}/missing", home) }
  assert File.file?("#{source}/productivity/first/SKILL.md")
  FileUtils.rm_r(Dir.children(source).map { |name| File.join(source, name) })
  2.times { sync_user_skill_links(source, home) }
  assert Dir.empty?(source)
  destinations.each do |directory|
    assert Dir.children(directory).sort == %w[omarchy personal similar-prefix unrelated]
    assert File.read("#{directory}/personal/SKILL.md") == 'personal skill'
    assert File.readlink("#{directory}/omarchy") == '/usr/share/omarchy/default/agents/skills/omarchy'
    assert File.readlink("#{directory}/unrelated") == "#{root}/unrelated-missing"
    assert File.readlink("#{directory}/similar-prefix") == "#{File.dirname(source)}-other/missing"
  end
  assert File.read("#{home}/.codex/skills/.system/keep") == 'system skill'

  # A same-name directory, file, or unrelated symlink is never adopted or overwritten.
  FileUtils.mkdir_p("#{source}/productivity/collision")
  File.write("#{source}/productivity/collision/SKILL.md", 'collision skill')
  collision = "#{destinations.last}/collision"
  [:directory, :file, :symlink].each do |kind|
    case kind
    when :directory then FileUtils.mkdir_p(collision)
    when :file then File.write(collision, 'keep')
    when :symlink then File.symlink("#{root}/missing", collision)
    end
    assert_refused('not managed by Archon') { sync_user_skill_links(source, home) }
    assert File.lstat(collision).ftype == kind.to_s.sub('symlink', 'link')
    assert File.read("#{source}/productivity/collision/SKILL.md") == 'collision skill'
    assert !path_exists?("#{destinations.first}/collision")
    FileUtils.rm_r(collision)
  end
end

puts 'PASS skills: repeated sync, updates, deletions, empty source, link ownership, collisions, and preservation'
