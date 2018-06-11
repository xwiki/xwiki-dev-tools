#! /bin/sh
if [ "${WL_PATH}" != "" ]; then
  cd $WL_PATH
fi
nCommits=0
git rm --cached -r .translation/ && git commit --amend --no-edit --allow-empty
if [ $? = 0 ]; then
  nCommits=$((nCommits+1))
fi
git add . && git reset .translation/ && git commit -m "[Translation] Update translations"
if [ $? = 0 ]; then
  nCommits=$((nCommits+1))
fi
# Remove commits if empty
git filter-branch -f --prune-empty @~$nCommits..
