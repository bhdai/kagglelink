# kagglelink

A streamlined solution for accessing Kaggle computational resources via SSH and VS Code, powered by Zrok for secure tunneling.

## Overview

KaggleLink allows you to connect to Kaggle environments via SSH, enabling you to leverage Kaggle's computational resources

![](https://github.com/user-attachments/assets/db4454ff-5545-4094-adeb-47b74ab0c33a)

## Getting Started

### Requirements

To use KaggleLink, you need:

1.  **Zrok Token**: A Zrok token is essential for establishing the secure tunnel. Create an account at [myZrok.io](https://myzrok.io/) to obtain your token. Ensure your account is on the **Starter plan** to utilize NetFoundry's public Zrok instance, which offers 2 environment connections (one for your local machine, one for the Kaggle instance).
2.  **Public SSH Key**: Your public SSH key needs to be accessible via a URL, either from a GitHub repository or another public file hosting service.

### Quick Setup (on Kaggle)

Execute the following one-line command in a Kaggle notebook cell. This script will set up Zrok and SSH on your Kaggle instance.

```bash
!curl -sS https://bhdai.github.io/setup | bash -s -- -k <public_key_url> -t <zrok_token>
```

> [!NOTE]
> Replace `<public_key_url>` with the URL of your public SSH key file and `<zrok_token>` with your Zrok token.

Wait for the setup to complete. You should see output similar to this upon successful configuration:

![](https://github.com/user-attachments/assets/22f564f3-8622-4c6c-bb82-9c9c63dd322a)

#### How to set up your public SSH key?

1.  **Generate an SSH key pair** on your local machine (if you haven't already). Use a descriptive filename, for example:

    ```bash
    ssh-keygen -t rsa -b 4096 -C "kaggle_remote_ssh" -f ~/.ssh/kaggle_rsa
    ```

2.  **Upload your public key** (`~/.ssh/kaggle_rsa.pub`) to a public GitHub repository or a similar public file hosting service.
3.  **Obtain the Raw URL**: Navigate to your uploaded public key file in your repository and click the "Raw" button.

    ![](https://private-user-images.githubusercontent.com/140616004/444039100-ec9a884c-1c97-4be6-bd6d-03ac5dd16de7.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NjU0NjQyMzMsIm5iZiI6MTc2NTQ2MzkzMywicGF0aCI6Ii8xNDA2MTYwMDQvNDQ0MDM5MTAwLWVjOWE4ODRjLTFjOTctNGJlNi1iZDZkLTAzYWM1ZGQxNmRlNy5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjUxMjExJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI1MTIxMVQxNDM4NTNaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT04YjZiY2M1OWRiMDUzYWZiMDUwODUzMjg2NDA4ZTU5NDAxZTM3YWU3ZGJmMDRlMjFiZjA0YmFmOGJlNTJmNzg1JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.wDGsBk1CyVVAWFLSGh8wRldUbz2hiAOzw6t3Zf39K5A)

    Copy the URL from your browser's address bar. It typically looks like `https://raw.githubusercontent.com/<username>/<repo_name>/refs/heads/main/<file_path>`.

#### How to get your Zrok token?

1.  If you don't have one, create your Zrok account at [myZrok.io](https://myzrok.io/).
2.  Go to the [billing page](https://myzrok.io/billing) and ensure your plan is set to **Starter**.
3.  Create a new token.
4.  Visit [https://api-v1.zrok.io](https://api-v1.zrok.io/) to retrieve and manage your Zrok tokens.

### Advanced: Environment Variables

For automated pipelines or power users, you can configure KaggleLink using environment variables instead of CLI flags.

| Variable | CLI Equivalent | Description |
|----------|----------------|-------------|
| `KAGGLELINK_KEYS_URL` | `-k` | URL to your public SSH key |
| `KAGGLELINK_TOKEN` | `-t` | Your Zrok token |

> [!NOTE]
> CLI arguments (`-k`, `-t`) always override environment variables if both are present.

#### Setting Environment Variables in Kaggle

The most secure way to pass these credentials is using **Kaggle Secrets**.

1.  Add your secrets in the Kaggle notebook sidebar (**Add-ons** -> **Secrets**).
2.  Use the following Python snippet in a cell *before* running the setup script:

```python
from kaggle_secrets import UserSecretsClient
import os

user_secrets = UserSecretsClient()

# Set environment variables from secrets
# Ensure you have added 'KAGGLELINK_TOKEN' and 'KAGGLELINK_KEYS_URL' (optional) to your secrets
os.environ['KAGGLELINK_TOKEN'] = user_secrets.get_secret("KAGGLELINK_TOKEN")

# You can also set the URL directly if it's public and not stored as a secret
os.environ['KAGGLELINK_KEYS_URL'] = "https://raw.githubusercontent.com/your/repo/main/key.pub"
```

Once the environment variables are set, you can run the setup script without arguments:

```bash
!curl -sS https://bhdai.github.io/setup | bash
```

## Usage

After completing the Kaggle setup, your Kaggle instance is ready for connection. The script will output a Zrok private token at the end which you'll use to connect from your local machine.

### Client Setup (on your Local Machine)

1.  **Install Zrok locally**: Follow the [official Zrok installation guide](https://docs.zrok.io/docs/guides/install/).
    For Arch-based distributions, you can use:

    ```bash
    yay -S zrok-bin
    ```

2.  **Enable Zrok**: Enable Zrok on your local machine using your personal Zrok token:

    ```bash
    zrok enable <your_personal_zrok_token>
    ```

3.  **Access the private tunnel**: Use the Zrok `private_token` obtained from the Kaggle setup output to establish the connection:

    ```bash
    zrok access private <the_private_token_from_kaggle_setup>
    ```

    This command will open a dashboard in your terminal, displaying your connection details, including a local address like `127.0.0.1:9191`.

### SSH Connection

Connect to your Kaggle instance via SSH using the local address and port provided by Zrok (e.g., `127.0.0.1:9191`).

```bash
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191 root@127.0.0.1
```

> [!NOTE]
> The port (e.g., 9191) generally remains consistent across sessions, so you typically won't need to adjust it for each new instance.

#### SSH Configuration

To simplify future connections, add the following configuration to your `~/.ssh/config` file:

```
Host Kaggle
    HostName 127.0.0.1
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/kaggle_rsa
    Port 9191
    User root
```

With this configuration, you can simply use `ssh Kaggle` to connect.

### File Transfer with Rsync

Transfer files between your local machine and Kaggle instance using `rsync`:

```bash
# From local to remote
rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191" <path_to_local_file> root@127.0.0.1:<remote_destination_path>
# or if you have you SSH config set up (see above)
rsync -avz <path_to_local_file> Kaggle:<remote_destination_path>

# From remote to local
rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191" root@127.0.0.1:<path_to_remote_file> <local_destination_path>
# or if you have you SSH config set up (see above)
rsync -avz Kaggle:<path_to_remote_file> <local_destination_path>
```

> [!IMPORTANT]
> The Zrok Starter plan limits you to two environment connections. While the script automatically releases the Kaggle instance's connection upon shutdown, it's good practice to verify your active connections at [https://api-v1.zrok.io/](https://api-v1.zrok.io/) before rerunning the script, ensuring your local machine is the primary active connection.

## Contributing

We welcome contributions to KaggleLink! If you're interested in improving this project, please follow these steps:

1.  **Fork the repository**.
2.  **Create a new branch** for your feature or bug fix (`git checkout -b feature/your-feature-name` or `bugfix/issue-description`).
3.  **Make your changes**, adhering to the existing coding style and standards.
4.  **Write and run tests** to ensure your changes work as expected and don't introduce regressions.
5.  **Commit your changes** with clear and concise commit messages.
6.  **Push your branch** to your forked repository.
7.  **Open a Pull Request** to the main branch, providing a detailed description of your changes.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
