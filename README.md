# CloudFront with Lambda@Edge

## Summary
This is a sample Terraform code to deploy CloudFront distribution with S3 bucket as an origin.
Sample Lambda@Edge function is also included to redirect HTTP request according to from which country the access was made.
Terraform code and Python code for Lambda@Edge function are designed to be as simple as possible, so this can be an entry point to manage CloudFront through Terraform.


## Environment used for Verification
This sample Terraform code is tested at [AWS CloudShell](https://aws.amazon.com/cloudshell/) on Northern Virginia Region.
Command result of `uname` was as follows.

```
$ uname -a
Linux ip-10-130-87-244.ec2.internal 6.1.66-91.160.amzn2023.x86_64 #1 SMP PREEMPT_DYNAMIC Wed Dec 13 04:50:24 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
```

Terraform is not installed in CloudShell by default.
Terraform can be installed through following commands.

```
$ sudo yum install -y yum-utils shadow-utils
$ sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
$ sudo yum -y install terraform
```


## Deployment
To deploy an [Amazon CloudFront](https://aws.amazon.com/cloudfront/) distribution with sample [Lambda@Edge](https://aws.amazon.com/lambda/edge/) function, there are 3 steps.
First, clone this repository.
Second, initialize Terraform.
Lastly, deploy resources through `terraform apply`.

```
$ # STEP 1: Clone repository.
$ git clone https://github.com/sk8393/terraform-cloudfront-lambda-edge.git
```

```
$ # Change directory to terraform-cloudfront-lambda-edge.
$ cd terraform-cloudfront-lambda-edge/
```

```
terraform-cloudfront-lambda-edge $ # Check Terraform code (main.tf) and Lambda@Edge code (index.py) exist.
terraform-cloudfront-lambda-edge $ ls -l
total 20
-rw-r--r--. 1 cloudshell-user cloudshell-user 1188 Feb  4 19:53 index.py
-rw-r--r--. 1 cloudshell-user cloudshell-user 1071 Feb  4 19:53 LICENSE
-rw-r--r--. 1 cloudshell-user cloudshell-user 5527 Feb  4 19:53 main.tf
-rw-r--r--. 1 cloudshell-user cloudshell-user   34 Feb  4 19:53 README.md
```

```
terraform-cloudfront-lambda-edge $ # STEP 2: Initialize Terraform.
terraform-cloudfront-lambda-edge $ terraform init
```

Below are the plugins and their versions when deployment completed successfully.

```
Initializing provider plugins...
- Finding latest version of hashicorp/archive...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/random...
- Installing hashicorp/archive v2.4.2...
- Installed hashicorp/archive v2.4.2 (signed by HashiCorp)
- Installing hashicorp/aws v5.35.0...
- Installed hashicorp/aws v5.35.0 (signed by HashiCorp)
- Installing hashicorp/random v3.6.0...
- Installed hashicorp/random v3.6.0 (signed by HashiCorp)
```

```
terraform-cloudfront-lambda-edge $ # STEP 3: Deploy resources.  This can take approximately 5 minutes.  Especially aws_cloudfront_distribution takes time for creation.
terraform-cloudfront-lambda-edge $ terraform apply
```

Terraform asks you whether deployment can be really made.
Just enter `yes` against a prompt like below.

```
Plan: 17 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: 
```


## Usage
Once `terraform apply` completed successfully, check domain (e.g. **0123456789abcd.cloudfront.net**) of the new CloudFront distribution.
Domain can be confirmed from [AWS Management Console](https://us-east-1.console.aws.amazon.com/cloudfront/v4/home).
If you are not sure which CloudFront distribution is that you created, check it through **terraform.tfstate**.

```
terraform-cloudfront-lambda-edge $ # Sample command to read Amazon Resource Name (ARN) of CloudFront distribution.  'ECJG9OZREDEUT' is its ID.
terraform-cloudfront-lambda-edge $ grep distribution terraform.tfstate | grep '"arn":'
            "arn": "arn:aws:cloudfront::699884809194:distribution/ECJG9OZREDEUT",
```

Once you accessed to the domain URL, you will be redirected to 1) **index.html**, or 2) **de/index.html**, or 3) **ie/index.html**.
This corresponds to the objects structure of the origin [Amazon Simple Storage Service (S3)](https://aws.amazon.com/s3/) bucket as below (technically speaking, S3 has no concept of directory).

```
S3 bucket/
  |- index.html
  |- de/
  |    |- index.html
  |- ie/
       |- index.html
```

According to the country code set in **CloudFront-Viewer-Country** header, requests are redirected to either **de/index.html** in case of Germany, or **ie/index.html** in case of Ireland by Lambda@Edge.
For all other cases, request goes **index.html**.
Greetings for each country are recorded in index.html.


## Lambda@Edge Destroy Issue
Deleting the replicated Lambda@Edge functions takes time.
In order to perform this deletion in a timely manner, we first have to remove the function association in the CloudFront distribution.
To do this on AWS Management Console, go to **Behaviors** tab, select behavior of path pattern **/index.html** and **Edit**, then turn **Origin request** back to **No association** (and **Save changes**).

![Screenshot 2024-02-06 at 20 57 16](https://github.com/sk8393/terraform-cloudfront-lambda-edge/assets/13175031/69d9f0c7-e9c4-44f5-8d32-1bfc70300411)

After waiting for 5 minutes or longer, execute `terraform destroy` to delete resources via Terraform.

Without following this step, you should see an error message like below.
Even if you saw this error message, you should be able to delete Lambda@Edge function as it has lost association from CloudFront (Terraform deletes CloudFront distribution first, Lambda@Edge function deletion failure happens later).

```
│ Error: deleting Lambda Function (suitably-smiling-ladybird): operation error Lambda: DeleteFunction, https response error StatusCode: 400, RequestID: 399a9efa-95e0-4cdf-b326-2174f49c106b, InvalidParameterValueException: Lambda was unable to delete arn:aws:lambda:us-east-1:699884809194:function:suitably-smiling-ladybird:1 because it is a replicated function. Please see our documentation for Deleting Lambda@Edge Functions and Replicas.
```
