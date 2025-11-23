import getpass

def input_yes_no(prompt):
    while True:
        choice = input(prompt).strip().lower()
        if choice in ("y", "yes"):
            return True
        if choice in ("n", "no"):
            return False
        print("Please answer with 'y' or 'n'.")

def input_password(prompt):
    while True:
        password = getpass.getpass(prompt)

        if not password:
            print("Password cannot be empty. Please try again.")
            continue

        password_confirm = getpass.getpass("Confirm password: ")
        if password != password_confirm:
            print("Passwords do not match. Please try again.")
            continue

        return password
