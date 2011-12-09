git reset --hard
git clean -dxf
git co master
git branch -D release-${VERSION}
git tag -d `mvn help:evaluate -Dexpression='project.artifactId' -N | grep -v '\[' | grep -v 'Downloading'`-${VERSION}