#!/bin/bash
open http://localhost:1313/
#hugo server --theme=hugo-theme-minos --buildDrafts
#hugo server --buildDrafts
hugo server -t kiera --buildDrafts
