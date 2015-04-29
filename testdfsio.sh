#!/bin/bash
 
#basic setup
#private static String getBaseDir(Configuration conf) {
#    return conf.get("test.build.data","/benchmarks/TestDFSIO");
#}
#sudo -u hdfs hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-test.jar TestDFSIO -write -nrFiles 10 -fileSize 1MB 
#sudo -u hdfs hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-test.jar TestDFSIO -read -nrFiles 10 -fileSize 1MB 
#sudo -u hdfs hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-test.jar TestDFSIO -clean
 
readonly BLOCK_SIZES="128 256 512 50 10"
readonly NUM_FILES="1000 10000"
readonly HADOOP_JAR=/opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-test.jar
readonly HDFS_WORK_DIR=/tmp/benchmarks/TestDFSIO
 
for num_files in $NUM_FILES; do
  for block_size_mb in $BLOCK_SIZES; do
    file_size_mb=$(( 1000000 / num_files ))
    block_size_bytes=$(( block_size_mb * 1024 * 1024 ))
    result_file="TestDFSIO_results_${num_files}_${file_size_mb}MB_blocksize_${block_size_mb}MB.log"
    echo "# $result_file"
    hadoop jar $HADOOP_JAR TestDFSIO -Dtest.build.data=$HDFS_WORK_DIR -Ddfs.block.size=${block_size_bytes} \
      -write -nrFiles $num_files -fileSize ${file_size_mb}MB -resFile $result_file
    hadoop jar $HADOOP_JAR TestDFSIO -Dtest.build.data=$HDFS_WORK_DIR -Ddfs.block.size=${block_size_bytes} \
      -read  -nrFiles $num_files -fileSize ${file_size_mb}MB -resFile $result_file
    hadoop jar $HADOOP_JAR TestDFSIO -Dtest.build.data=$HDFS_WORK_DIR -clean  done
  done
done
