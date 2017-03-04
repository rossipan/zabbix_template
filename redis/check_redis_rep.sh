#!/bin/bash

start=`date +%s.%N`
redis-cli info >/dev/null
end=`date +%s.%N`

runtime=$(python -c "print(${end} - ${start})")
echo $runtime