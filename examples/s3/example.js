var AWS = require('aws-sdk');

AWS.config.update({accessKeyId:'access-test', secretAccessKey:'secret-test'});
AWS.config.update({region:'default'});
AWS.config.update({endpoint:'http://172.16.35.100:8080'});

var s3 = new AWS.S3();
s3.listBuckets(function(err, data) {
   if (err) {
      console.log("Error", err);
   } else {
      console.log("Bucket List", data.Buckets);
   }
});
