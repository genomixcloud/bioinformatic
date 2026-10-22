ubuntu@ip-10-0-10-89:~$ sudo mkdir -p /mnt/sdb
ubuntu@ip-10-0-10-89:~$ sudo chown ubuntu:ubuntu /mnt/sdb
ubuntu@ip-10-0-10-89:~$ sudo mount /dev/xvdb /mnt/sdb
ubuntu@ip-10-0-10-89:~$ mkdir -p /mnt/sdb/kraken_db
mkdir: cannot create directory ‘/mnt/sdb/kraken_db’: Permission denied
ubuntu@ip-10-0-10-89:~$ sudo chown ubuntu:ubuntu /mnt/sdb
ubuntu@ip-10-0-10-89:~$ mkdir -p /mnt/sdb/kraken_db
ubuntu@ip-10-0-10-89:~$ vi install_kraken2_ubuntu.sh
ubuntu@ip-10-0-10-89:~$ chmod 755 install_kraken2_ubuntu.sh



==>  wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20251015.tar.gz
     tar -xvzf k2_standard_20251015.tar.gz -C /mnt/sdb/kraken_db/
          
standard  https://genome-idx.s3.amazonaws.com/kraken/k2_standard_20260226.tar.gz


https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08_GB_20260226.tar.gz

export PATH=$HOME/bin:/home/ubuntu/kraken2_install_dir:$PATH


Kraken/Braken BD:

https://benlangmead.github.io/aws-indexes/

Teaching documentation:
https://www.langmead-lab.org/teaching.html



https://zenodo.org/records/4066768/files/db.tar.gz