#!/bin/sh

rsync -a --delete .build/CorrectMe.app/ /Applications/CorrectMe.app/
correctme restart
