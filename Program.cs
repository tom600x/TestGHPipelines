var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRouting();

var app = builder.Build();

app.UseExceptionHandler(_ => { });

app.UseRouting();

app.MapGet("/", () => Results.Text("Azure App Service deployment test is running.", "text/plain"));
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.Run();
