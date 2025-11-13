import getpass

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
