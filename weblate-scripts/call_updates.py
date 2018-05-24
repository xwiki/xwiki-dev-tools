import argparse
import os
import re
import sys

POST_UPDATE_SCRIPT = './post_update.sh'
PRE_COMMIT_SCRIPT = './pre_commit.sh'

def update_project(project, vcs_path):
    file_name = 'translation_list_{}.txt'.format(project)
    project_path = vcs_path + project
    if not path_exists(project_path) or not path_exists(file_name):
        return
    with open(file_name, 'r') as f:
        repo_urls = {}
        for line in f.read().splitlines():
            if not line or line[0] == '#':
                continue
            name, path, repo_url = line.rsplit(';', 2)
            name, path, repo_url = name.strip(), path.strip(), repo_url.strip()
            slug = name.lower().replace(' ', '-').replace('.', '-')
            if repo_url not in repo_urls:
                repo_urls[repo_url] = project_path + '/' + slug
            repo_path = repo_urls[repo_url]
            basename = path.rsplit('.', 1)[0]
            filemask = '.translation/' + basename + '_*.properties'

            if not path_exists(repo_path):
                continue

            os.environ['WL_PATH'] = repo_path
            os.environ['WL_FILEMASK'] = filemask
            os.system(POST_UPDATE_SCRIPT)
            os.system(PRE_COMMIT_SCRIPT)

def path_exists(path):
    if not os.path.exists(path):
        print "Path {} doesn't exists".format(path)
        return False
    return True

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Call post update and pre commit scripts.')
    parser.add_argument('vcs_path', metavar='vcs_path', help='Path to Weblate VCS folder')
    parser.add_argument('--project', metavar='project', help='Project name')
    args = parser.parse_args()
    if args.vcs_path and args.vcs_path[-1] != '/':
        args.vcs_path += '/'

    if not path_exists(args.vcs_path):
        sys.exit(1)

    if args.project:
        update_project(args.project, args.vcs_path)
    else:
        for file_name in os.listdir(os.getcwd()):
            match = re.search(r'translation_list_(.*).txt', file_name)
            if not match:
                continue
            project = match.group(1)
            update_project(project, args.vcs_path)
