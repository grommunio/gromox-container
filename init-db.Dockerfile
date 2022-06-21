FROM olam1k0/grommunio:latest

# Set up DB
# Run an ephemeral container to populate this data. Use the command below as entrypoint
ENTRYPOINT ["gromox-dbop", "-C"]


