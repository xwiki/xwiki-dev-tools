#! /bin/sh
git rm --cached -r .translation/
git commit --amend --no-edit --allow-empty
# Remove commit if empty
git filter-branch -f --prune-empty @~1..
