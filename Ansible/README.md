# Simple Ansible scripts

## The scripts

- `vim` Install and configure vim and set it as the default editor
- `sudoers` Add a user to a *sudo* group and set some commands to be executed without password

## Ansible and ansible-lint for development

On a Ubuntu development host:

```sh
# remove previous installed Ansible and Ansible-Lint, if installed ...
sudo apt remove ansible ansible-lint
# ... or purge them to also remove any configuration
# sudo apt purge ansible ansible-lint

# install them for user only
python3 -m pip install --user ansible
python3 -m pip install --user ansible-lint
```

To upgrade run:

```sh
python3 -m pip install --upgrade --user ansible
python3 -m pip install --upgrade --user ansible-lint
```
