#!/bin/bash

BLOCK_SIZES_MB="128 256 512 50 10"
NUM_FILES="1000 10000"
TOTAL_SIZE_MB=1000000
HADOOP_JAR=/opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-test.jar
HDFS_WORK_DIR=/tmp/benchmarks/TestDFSIO
RESULTS=all_results.tsv
 
rm -f $RESULTS
for num_files in $NUM_FILES; do
  for block_size_mb in $BLOCK_SIZES_MB; do
	file_size_mb=$(( $TOTAL_SIZE_MB / num_files ))
	block_size_bytes=$(( block_size_mb * 1024 * 1024 ))
	result_file="TestDFSIO_results_${num_files}_${file_size_mb}MB_blocksize_${block_size_mb}MB.log"
	echo "# $result_file"
    hadoop jar $HADOOP_JAR TestDFSIO -Dtest.build.data=$HDFS_WORK_DIR -Ddfs.block.size=${block_size_bytes} \
  	-write -nrFiles $num_files -fileSize ${file_size_mb}MB -resFile $result_file
    hadoop jar $HADOOP_JAR TestDFSIO -Dtest.build.data=$HDFS_WORK_DIR -Ddfs.block.size=${block_size_bytes} \
  	-read  -nrFiles $num_files -fileSize ${file_size_mb}MB -resFile $result_file
    hadoop jar $HADOOP_JAR TestDFSIO -Dtest.build.data=$HDFS_WORK_DIR -clean
    awk -v FILE=$result_file '
      /TestDFSIO/              {phase=$NF}
      /Number of files/        {num_files=$NF}
      /Total MBytes processed/ {total_mb=$NF}
      /Throughput mb.sec/      {throughput[phase]=$NF}
      /Average IO rate mb.sec/ {iorateavg[phase]=$NF}
      /IO rate std deviation/  {ioratestd[phase]=$NF}
      /Test exec time sec/ 	{exectime[phase]=$NF}
  
      END{printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", FILE, num_files, total_mb,
                                                                 throughput["write"], iorateavg["write"], ioratestd["write"], exectime["write"],
                                                                 throughput["read"], iorateavg["read"], ioratestd["read"], exectime["read"]
         }
    ' $result_file >> $RESULTS
 
  done
done
