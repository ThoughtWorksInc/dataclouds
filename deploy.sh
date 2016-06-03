#!/bin/bash

git config credential.https://github.com.username
git config core.askPass
hexo d -g
