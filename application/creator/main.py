from kubernetes import config, dynamic
from kubernetes.client import api_client
from flask import Flask, request
from waitress import serve
import json

#Initialize Kubernetes client
client_k8s = dynamic.DynamicClient(
    #api_client.ApiClient(configuration=config.load_incluster_config())
    api_client.ApiClient(configuration=config.load_kube_config())
)

#Create client for dynamodb
dynamodb = client_k8s.resources.get(
        api_version="dynamodb.services.k8s.aws/v1alpha1", kind="Table"
    )

##Create client for dynamodb
s3 = client_k8s.resources.get(
        api_version="s3.services.k8s.aws/v1alpha1", kind="Bucket"
    )


data_success = {"status": "success"}
data_failed = {"status": "failed"}
app = Flask(__name__)




#
# DynamoDB Endpoint
#

@app.route('/dynamodb', methods = ['POST', 'DELETE'])
def dynamo_handler():

  if request.method == "POST":

    try:
      result_json = request.data
      result_json = json.loads(result_json)


      dynamodb_manifest = {
        "apiVersion": "dynamodb.services.k8s.aws/v1alpha1",
        "kind": "Table",
        "metadata": {
          "name": result_json['name']
        },
        "spec": {
          "tableName": result_json['name'],
          "attributeDefinitions": [
            {
              "attributeName": "email",
              "attributeType": "S"
            },
            {
              "attributeName": "name",
              "attributeType": "S"
            }
          ],
          "keySchema": [
            {
              "attributeName": "email",
              "keyType": "HASH"
            },
            {
              "attributeName": "name",
              "keyType": "RANGE"
            }
          ],
          "provisionedThroughput": {
            "readCapacityUnits": 5,
            "writeCapacityUnits": 5
          }
        }
      }
      result = dynamodb.create(body=dynamodb_manifest, namespace="default")
      print(result)
      return data_success, 200
    except:
      print("Cold not get valid JSON on /dynamodb")
      return data_failed, 500

  elif request.method == "DELETE":

    try:
      result_json = request.data
      result_json = json.loads(result_json)
      result = dynamodb.delete(name=result_json['name'], namespace="default")
      print(result)
      #print(result)
      return data_success, 200
    except:
      print("Cold not get valid JSON on /dynamodb")
      return data_failed, 500





#
# S3 Endpoint
#

@app.route('/s3', methods = ['POST', 'DELETE'])
def s3_handler():

  if request.method == "POST":

    try:
      result_json = request.data
      result_json = json.loads(result_json)
      s3_manifest = {
        "apiVersion": "s3.services.k8s.aws/v1alpha1",
        "kind": "Bucket",
        "metadata": {
          "name": result_json['name']
        },
        "spec": {
          "name": result_json['name']
        }
      }
      result = s3.create(body=s3_manifest, namespace="default")
      print(result)
      request.get_json(force=True)
    except:
      print("Cold not get valid JSON on /s3")
      return data_failed, 500

  elif request.method == "DELETE":

    try:
      result_json = request.data
      result_json = json.loads(result_json)
      result = s3.delete(name=result_json['name'], namespace="default")
      print(result)
      request.get_json(force=True)
    except:
      print("Cold not get valid JSON on /s3")
      return data_failed, 500


if __name__ == '__main__':
  serve(app, host="0.0.0.0", port=8080)

