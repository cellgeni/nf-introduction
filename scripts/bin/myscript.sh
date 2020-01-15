#!/bin/bash
set -euo pipefail

printf "${1?Need argument}" | split -b 10 - chunk_
