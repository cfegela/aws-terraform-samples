import { ECSClient, RunTaskCommand } from "@aws-sdk/client-ecs";

export const handler = async (event) => {
  const client = new ECSClient({ region: "us-east-2" });

  const params = {
    cluster: "edgar-ecs-cluster",
    taskDefinition: "arn:aws:ecs:us-east-2:609543642808:task-definition/sample-task:1",
    launchType: "FARGATE",
    enableExecuteCommand: true,
    networkConfiguration: {
      awsvpcConfiguration: {
        assignPublicIp: "DISABLED",
        securityGroups: ["sg-01f36755038d80d48"],
        subnets: ["subnet-0b71bfebd05e0ff53"],
      },
    },
  };

  try {
    const command = new RunTaskCommand(params);
    const data = await client.send(command);
    console.log("Task started successfully:", data);
    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Task started successfully", data }),
    };
  } catch (error) {
    console.error("Error starting task:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Error starting task", error }),
    };
  }
};
