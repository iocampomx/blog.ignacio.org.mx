#!/bin/bash
hugo -v
aws s3 sync --acl "public-read" public/ s3://blog.ignacio.org.mx --exclude 'post'
