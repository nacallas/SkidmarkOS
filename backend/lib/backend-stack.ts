import * as cdk from "aws-cdk-lib";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as apigw from "aws-cdk-lib/aws-apigatewayv2";
import * as integrations from "aws-cdk-lib/aws-apigatewayv2-integrations";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import * as path from "path";

export class BackendStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const roastFn = new lambda.Function(this, "RoastGenerator", {
      runtime: lambda.Runtime.PYTHON_3_12,
      handler: "roast_generator.handler",
      code: lambda.Code.fromAsset(path.join(__dirname, "..", "lambda")),
      timeout: cdk.Duration.seconds(60),
      memorySize: 1024,
      environment: {
        BEDROCK_MODEL_ID: "anthropic.claude-3-5-haiku-20241022-v1:0",
        BEDROCK_REGION: "us-west-2",
      },
    });

    roastFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["bedrock:InvokeModel"],
        resources: ["arn:aws:bedrock:*::foundation-model/*"],
      })
    );

    roastFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe",
        ],
        resources: ["*"],
      })
    );

    const api = new apigw.HttpApi(this, "SkidmarkApi", {
      apiName: "skidmark-api",
      corsPreflight: {
        allowOrigins: ["*"],
        allowMethods: [apigw.CorsHttpMethod.POST, apigw.CorsHttpMethod.OPTIONS],
        allowHeaders: ["Content-Type", "Authorization"],
      },
    });

    api.addRoutes({
      path: "/roasts/generate",
      methods: [apigw.HttpMethod.POST],
      integration: new integrations.HttpLambdaIntegration(
        "RoastIntegration",
        roastFn
      ),
    });

    new cdk.CfnOutput(this, "ApiUrl", {
      value: api.url ?? "MISSING",
      description: "Skidmark API endpoint URL",
    });
  }
}
