output "sample_invoke_arn" {
  value = aws_lambda_function.sample.invoke_arn
}

output "sample_function_name" {
  value = aws_lambda_function.sample.function_name
}

output "bedrock_sample_invoke_arn" {
  value = aws_lambda_function.bedrock-sample.invoke_arn
}

output "bedrock_sample_function_name" {
  value = aws_lambda_function.bedrock-sample.function_name
}

output "ecs_task_sample_invoke_arn" {
  value = aws_lambda_function.ecs-task-sample.invoke_arn
}

output "ecs_task_sample_function_name" {
  value = aws_lambda_function.ecs-task-sample.function_name
}
