# kagglelink

A streamlined solution for accessing Kaggle computational resources via SSH and VS Code, powered by Zrok for secure tunneling.

## Overview

kagglelink allows you to ssh into Kaggle and leverage those kaggle resources, or you can run kaggles notebook remotely using VSCode, with more coding support, and better development environment

![Image](https://github.com/user-attachments/assets/db4454ff-5545-4094-adeb-47b74ab0c33a)

## Requirements

1. A Zrok token is required for establishing the tunnel. Create an account at [myZrok.io](https://myzrok.io/) to get your token.

2. Ensure your account is on the Starter plan to utilize NetFoundry's public Zrok instance.

3. You need to upload your public key to a github repository or a public file hosting service

## Quick Setup

One line command setup?

Paste this into Kaggle cell

```bash
!curl -sS https://bhdai.github.io/setup.sh | bash -s -- -k <public_key_url> -t <zrok_token>
```

> [!NOTE]
>
> replace <public_key_url> with the URL of your public key file and <zrok_token> with your Zrok token.


Wait for the setup to finish, you should see something like this at the end

![Image](https://github.com/user-attachments/assets/22f564f3-8622-4c6c-bb82-9c9c63dd322a)

### How to setup public key?

Generate a new SSH key pair on your local machine (if you haven't already):

```bash
ssh-keygen -t rsa -b 4096 -C "kaggle_remote_ssh" -f ~/.ssh/kaggle_rsa
```

Create a github repository and push the `~/.ssh/kaggle_rsa.pub` file to it. Make sure the repository is public. Once finished, you can get the public key URL by navigating to the file in your repository and clicking on the "Raw" button. 

![Image](https://github.com/user-attachments/assets/ec9a884c-1c97-4be6-bd6d-03ac5dd16de7)

Copy the URL from your browser's address bar. It usually takes the form like this `https://raw.githubusercontent.com/<username>/<repo_name>/refs/heads/main/<file_path>`

### How to get zrok token?

Create your zrok account, if you haven't already, go [here](https://myzrok.io/billing) and change your plan to Starter plan, and then create a new token. Finally visit [https://api-v1.zrok.io](https://api-v1.zrok.io/), you should setup and get your token there

## Client Setup

After completing the Kaggle setup, you'll receive a token. Follow these steps on your local machine:

1. Install Zrok locally by following the [official installation guide](https://docs.zrok.io/docs/guides/install/).

   For Arch-based distributions, you can use:
   ```bash
   yay -S zrok-bin
   ```

2. Enable zrok in your local machine
      ```bash
      zrok enable <zrok-token>
      ```

2. Access your Kaggle instance using the token:
   ```bash
   zrok access private <the_token_from_kaggle>
   ```

3. This will open a dashboard displaying your connection details, including a local address like `127.0.0.1:9191`.

## SSH Connection

*For VSCode check out the [old instrunction](https://github.com/bhdai/kagglelink/blob/ngrok/README.md#connect-via-ssh) (will update this eventually)*

Connect to your Kaggle instance via SSH:

```bash
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191 root@127.0.0.1
```

Note: The port (e.g., 9191) generally remains consistent across sessions, so no need to adjust it for each new instance.

### SSH Configuration

To simplify future connections, add this configuration to your `~/.ssh/config` file:

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

## File Transfer with Rsync

Transfer files between your local machine and Kaggle instance:

```bash
# From local to remote
rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191" <path_to_local_file> root@127.0.0.1:/kaggle/working

# From remote to local
rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/kaggle_rsa -p 9191" root@127.0.0.1:<path_to_remote_file> <local_destination_path>
```

> [!NOTE]
>
> If you're using the Starter plan, they only offer 2 environment connection on this plan one for you local machine, one for kaggle instance. While the script will automatically release the Kaggle instance when you turn off Kaggle, but it's best to check [https://api-v1.zrok.io/](https://api-v1.zrok.io/) to make sure your local machine is connected and there are no other active connections.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
