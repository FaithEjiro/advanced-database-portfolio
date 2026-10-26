#!/usr/bin/env bash
# CarePoint: 3-node MongoDB replica set in Docker (Portfolio 5)
# One node per branch: rs1 = Wuse, rs2 = Garki, rs3 = Maitama
set -e
sudo docker network create carepoint-net || true
for n in 1 2 3; do
  sudo docker run -d --name carepoint-rs$n --network carepoint-net \
    mongo:8 --replSet carepoint-rs --bind_ip_all
done
sleep 10
sudo docker exec carepoint-rs1 mongosh --quiet --eval 'rs.initiate({_id: "carepoint-rs", members: [
  {_id: 0, host: "carepoint-rs1:27017"},
  {_id: 1, host: "carepoint-rs2:27017"},
  {_id: 2, host: "carepoint-rs3:27017"}]})'
sleep 15
sudo docker exec carepoint-rs1 mongosh --quiet --eval 'rs.status().members.map(m => m.name + "  " + m.stateStr)'
