# System checklist

## Remote git server
Purpose is to validate connectivity to git repo
- [ ]  Setup an empty repository on the git server
```shell
[from git VM]
cd /home/git/
mkdir <directory_name>  e.g. mkdir redhat.git
cd redhat.git
git init --bare
```
- [ ] Add files from the Business Central VM
```shell
[from Business Central VM]
cd /home/git_repositories
mkdir redhat $$ cd redhat
git init
echo "Initial commit" >> file.txt
git add .
git commit -m '<commit message>’
git remote add origin git@<GIT SERVER IP>:/home/git/redhat.git
git push origin master
```
- [ ] Clone and verify the changes
```shell
cd /home/git_repositories
rm -rf redhat
git clone git@<GIT SERVER IP>:/home/git/redhat.git
```
- [ ] Update files
```shell
echo "Next commit" >> file.txt
git add .
git commit -m '<commit message>’
git push origin master
```
- [ ] Repeat clone test and verify the changes


