#!/bin/bash
cd /workspaces/MASLIVE
git push origin main 2>&1
echo "Push terminé avec code: $?"
