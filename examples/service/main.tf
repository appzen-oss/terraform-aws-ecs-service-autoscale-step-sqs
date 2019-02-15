module "example" {
  source       = "../../"
  cluster_name = "test_cluster"
  queue_name   = "test_sqs"
  service_name = "test_ecs_srv"
}
