def parse_file_entries(file_path):
    packages = []
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            # Extract package name before any comment.
            package = line.split(maxsplit=1)[0]
            if package:
                packages.append(package)
    return packages