#!/bin/bash

trap "docker stack rm erasureservice" EXIT

FILENAME=erasure.yaml
EXPORT_FILENAME=erasure-temp.yaml

ORIGINAL_STRING=thecmd
QTY_STRING=theqty

FILENAME2="experiments"
LINES=$(cat $FILENAME2 | grep "^[^#;]")

# Each LINE in the experiment file is one experimental setup
for LINE in $LINES
do
  mkdir ../experiments/$LINE
  echo '---------------------------------------------------------------'
  echo $LINE
  IFS=':' read -ra split <<< "$LINE"

  sed  "s/${ORIGINAL_STRING}/${split[0]}/g" $FILENAME > $EXPORT_FILENAME
  sed  -i "s/${QTY_STRING}/${split[1]}/g" $EXPORT_FILENAME

  echo '**********************************************'
  echo "*** This setup needs ${split[2]} physical machines! ***"
  echo '**********************************************'

  for i in {1..3}
  do
        # Deploy experiment
        docker stack deploy -c erasure-temp.yaml erasureservice &
        # Docker startup time + 3*60s of experiment runtime
        sleep 330

        # Collect and print results.
        for container in $(docker ps -q -f name="server")
        do
                if [ ! $(docker exec -it $container bash -c "cd libhotstuff_erasure && test -e log0") ]
                then
                  docker exec -it $container bash -c "cd libhotstuff_erasure && tac log* | grep -m1 'commit <block'"
                  docker exec -it $container bash -c "cd libhotstuff_erasure && tac log* | grep -m1 'now state'"
                  docker exec -it $container bash -c "cd libhotstuff_erasure && tac log* | grep -m1 'Average'"
		              docker exec -it $container bash -c "cat libhotstuff_erasure/log* > libhotstuff_erasure/log$i"
                  docker cp $container:/libhotstuff_erasure/log$i ../experiments/$LINE
                  break
                fi
        done

        docker stack rm erasureservice
        sleep 20

  done
done
