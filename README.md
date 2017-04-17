# Quick Start Rados
Quick boot a Ceph cluster and compile rados-java jar. Major help to deploy a dev environment use for learning librados API and S3 SDK.

Easy enough! install [vagrant](http://www.vagrantup.com/downloads.html) and [virtualbox](https://www.virtualbox.org/wiki/Linux_Downloads):
```sh
$ wget https://releases.hashicorp.com/vagrant/1.9.2/vagrant_1.9.2_x86_64.deb
$ wget http://download.virtualbox.org/virtualbox/5.1.18/virtualbox-5.1_5.1.18-114002~Ubuntu~xenial_amd64.deb
$ sudo dpkg -i vagrant_1.9.2_x86_64.deb
$ sudo dpkg -i virtualbox-5.1_5.1.18-114002~Ubuntu~xenial_amd64.deb
```

Create a vm using vagrant with virtualbox. When the operation is completed, type `vagrant ssh <name>` into vm:
```sh
$ vagrant up
$ vagrant ssh ceph-aio
```

Finally, check the ceph cluster and run java example:
```sh
$ sudo ceph -s
$ cd examples
$ javac Example.java && sudo java Example
Put kyle-say
Put my-object

# use rados command check object
$ sudo rados -p data get my-object -
This is my object.
```

## Spark s3a example
This guide is talking about Spark get data from s3, you can follow below step to produce an environment use to testing.

First, go to `/vagrant` dir and run:
```sh
$ cd /vagrant
$ ./spark-initial.sh
$ jps
22194 SecondaryNameNode
22437 Jps
21350 ResourceManager
21469 NodeManager
21998 DataNode
21822 NameNode
```

And then put a data file to s3 using `s3client`:
```sh
$ ./create-s3-account.sh
$ source test-key.sh
$ ./s3client create files
$ cat <<EOF > words.txt
AA A CC AA DD AA EE AE AE
CC DD AA EE CC AA AA DD AA EE AE AE
EOF

$ ./s3client upload files words.txt /
Upload [words.txt] success ...
```

Now launch spark-shell to type the follow steps:
```sh
$ spark-shell --master yarn
scala> val textFile = sc.textFile("s3a://files/words.txt")
textFile: org.apache.spark.rdd.RDD[String] = s3a://files/words.txt MapPartitionsRDD[1] at textFile at <console>:24

scala> val counts = textFile.flatMap(line => line.split(" ")).map(word => (word, 1)).reduceByKey(_ + _)
counts: org.apache.spark.rdd.RDD[(String, Int)] = ShuffledRDD[4] at reduceByKey at <console>:26

scala> counts.saveAsTextFile("s3a://files/output")
[Stage 0:>                                                          (0 + 2) / 2]
```

Use `s3client` list output files:
```sh
$ ./s3client list files
---------- [files] ----------
output/_SUCCESS     	0                   	2017-03-28T17:06:59.775Z
output/part-00000   	35                  	2017-03-28T17:06:58.413Z
output/part-00001   	6                   	2017-03-28T17:06:59.056Z
words.txt           	44                  	2017-03-28T17:04:33.141Z
```

You also can use `hdfs` command to list and cat file:
```sh
$ hadoop fs -ls s3a://files/output
Found 3 items
-rw-rw-rw-   1          0 2017-03-28 17:06 s3a://files/output/_SUCCESS
-rw-rw-rw-   1         35 2017-03-28 17:06 s3a://files/output/part-00000
-rw-rw-rw-   1          6 2017-03-28 17:06 s3a://files/output/part-00001

$ hadoop fs -cat s3a://files/output/part-00000
(DD,2)
(EE,2)
(AE,2)
(CC,3)
(AA,5)
```
