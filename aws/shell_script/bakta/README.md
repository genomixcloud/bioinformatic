export PATH=$HOME/bin:/home/ubuntu/miniconda3/bin:$PATH
source activate bakta_env


sudo chown -R ubuntu:ubuntu /mnt/efs/bakta_db
bakta_db download --output /mnt/sdb/bakta_db --type full

bakta downloads:
https://github.com/oschwengers/bakta/blob/main/README.md#database-download

bakta_db download --output <output-path> --type [light|full]

bakta_db download --output /mnt/efs/ --type light

db-light +> you can rename  your dir 

r5.2xlarge para evitar un kill por memory 