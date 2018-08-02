#!/bin/bash
hugo -v -t kiera
aws s3 sync --acl "public-read" public/ s3://blog.nafiux.com --exclude 'post' --profile usr-nafiux-iocampo
