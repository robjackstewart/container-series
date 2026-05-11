var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume()
    .WithPgAdmin();

var redis = builder.AddRedis("redis")
    .WithRedisInsight();

var rabbitmq = builder.AddRabbitMQ("rabbitmq")
    .WithManagementPlugin();

var orderDb = postgres.AddDatabase("orderdb");

var orderService = builder.AddProject<Projects.ContainerSeries_OrderService>("orderservice")
    .WithReference(orderDb)
    .WithReference(rabbitmq);

var notificationService = builder.AddProject<Projects.ContainerSeries_NotificationService>("notificationservice")
    .WithReference(rabbitmq);

var api = builder.AddProject<Projects.ContainerSeries_Api>("api")
    .WithReference(orderService)
    .WithReference(redis);

var web = builder.AddProject<Projects.ContainerSeries_Web>("web")
    .WithReference(api);

builder.Build().Run();
