#Instructions for running FSL Feat docker container on cluster

#Build the docker image in your terminal window inside the folder where your dockerfile_cluster is saved

#This command will create an image named recover_container in the current directory

docker build -t recover_container .

#wait for container to finish building

#run container, the -v will mount the local directory where your script are to the /usr/local/bin #inside the container, followed by the subject IDs you want to run (some may have letters in front #like UPN-050)

docker run -v /project/fischer/PREDICT/docker_cluster:/usr/local/bin recover_container 001 002 003