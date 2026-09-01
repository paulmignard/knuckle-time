using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// Configure JSON to be case-insensitive (iOS sends camelCase, C# expects PascalCase by default)
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNameCaseInsensitive = true;
});

// Configuration
var clientId = builder.Configuration["Harvest:ClientId"]
    ?? throw new InvalidOperationException("Harvest:ClientId not configured");
var clientSecret = builder.Configuration["Harvest:ClientSecret"]
    ?? throw new InvalidOperationException("Harvest:ClientSecret not configured");
var apiKey = builder.Configuration["ApiKey"]; // Optional: for app verification

// Log configuration status at startup (helps debug Railway env vars)
Console.WriteLine($"[Startup] Config loaded - ClientId length: {clientId.Length}, SecretLength: {clientSecret.Length}");

// Services
builder.Services.AddHttpClient("Harvest", client =>
{
    client.BaseAddress = new Uri("https://id.getharvest.com/");
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
    client.DefaultRequestHeaders.UserAgent.ParseAdd("KnuckleTime-AuthProxy/1.0");
});

// Rate limiting - 30 requests per minute per IP
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1)
            }));
});

var app = builder.Build();

app.UseRateLimiter();

// Health check for Railway
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));

// OAuth callback - redirects to iOS app with the authorization code
app.MapGet("/oauth/callback", (string? code, string? error, string? error_description) =>
{
    if (!string.IsNullOrEmpty(error))
    {
        // Redirect to app with error
        var errorUri = $"knuckle://oauth/callback?error={Uri.EscapeDataString(error)}&error_description={Uri.EscapeDataString(error_description ?? "")}";
        return Results.Redirect(errorUri);
    }

    if (string.IsNullOrEmpty(code))
    {
        var errorUri = "knuckle://oauth/callback?error=missing_code&error_description=No+authorization+code+received";
        return Results.Redirect(errorUri);
    }

    // Redirect to iOS app with the code
    var redirectUri = $"knuckle://oauth/callback?code={Uri.EscapeDataString(code)}";
    return Results.Redirect(redirectUri);
});

// Token exchange endpoint
app.MapPost("/auth/token", async (TokenRequest request, IHttpClientFactory httpClientFactory) =>
{
    // Debug logging
    app.Logger.LogInformation("Token request received - Code: {CodeLength} chars, RedirectUri: {RedirectUri}",
        request.Code?.Length ?? 0, request.RedirectUri ?? "(null)");

    if (string.IsNullOrWhiteSpace(request.Code))
        return Results.BadRequest(new { error = "code is required" });

    if (string.IsNullOrWhiteSpace(request.RedirectUri))
        return Results.BadRequest(new { error = "redirect_uri is required" });

    var client = httpClientFactory.CreateClient("Harvest");

    // Log what we're sending (without exposing full secret)
    app.Logger.LogInformation("Sending to Harvest - ClientId: {ClientId}, SecretLength: {SecretLength}, RedirectUri: {RedirectUri}",
        clientId, clientSecret?.Length ?? 0, request.RedirectUri);

    var tokenRequest = new FormUrlEncodedContent([
        new KeyValuePair<string, string>("grant_type", "authorization_code"),
        new KeyValuePair<string, string>("code", request.Code),
        new KeyValuePair<string, string>("client_id", clientId),
        new KeyValuePair<string, string>("client_secret", clientSecret),
        new KeyValuePair<string, string>("redirect_uri", request.RedirectUri)
    ]);

    try
    {
        var response = await client.PostAsync("api/v2/oauth2/token", tokenRequest);
        var content = await response.Content.ReadAsStringAsync();
        
        if (!response.IsSuccessStatusCode)
        {
            app.Logger.LogWarning("Harvest token exchange failed: {StatusCode} - {Content}", 
                response.StatusCode, content);
            return Results.Problem(
                detail: "Token exchange failed",
                statusCode: (int)response.StatusCode);
        }

        var tokenResponse = JsonSerializer.Deserialize<HarvestTokenResponse>(content);
        
        return Results.Ok(new TokenResponse(
            tokenResponse!.AccessToken,
            tokenResponse.RefreshToken,
            tokenResponse.ExpiresIn,
            tokenResponse.TokenType
        ));
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Error during token exchange");
        return Results.Problem(detail: "Internal server error", statusCode: 500);
    }
})
.RequireRateLimiting("auth");

// Token refresh endpoint
app.MapPost("/auth/refresh", async (RefreshRequest request, IHttpClientFactory httpClientFactory) =>
{
    if (string.IsNullOrWhiteSpace(request.RefreshToken))
        return Results.BadRequest(new { error = "refresh_token is required" });

    var client = httpClientFactory.CreateClient("Harvest");
    
    var refreshRequest = new FormUrlEncodedContent([
        new KeyValuePair<string, string>("grant_type", "refresh_token"),
        new KeyValuePair<string, string>("refresh_token", request.RefreshToken),
        new KeyValuePair<string, string>("client_id", clientId),
        new KeyValuePair<string, string>("client_secret", clientSecret)
    ]);

    try
    {
        var response = await client.PostAsync("api/v2/oauth2/token", refreshRequest);
        var content = await response.Content.ReadAsStringAsync();
        
        if (!response.IsSuccessStatusCode)
        {
            app.Logger.LogWarning("Harvest token refresh failed: {StatusCode} - {Content}", 
                response.StatusCode, content);
            
            // 401 likely means refresh token is invalid/expired - user needs to re-auth
            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                return Results.Json(
                    new { error = "invalid_grant", error_description = "Refresh token is invalid or expired" },
                    statusCode: 401);
            }
            
            return Results.Problem(
                detail: "Token refresh failed",
                statusCode: (int)response.StatusCode);
        }

        var tokenResponse = JsonSerializer.Deserialize<HarvestTokenResponse>(content);
        
        return Results.Ok(new TokenResponse(
            tokenResponse!.AccessToken,
            tokenResponse.RefreshToken,
            tokenResponse.ExpiresIn,
            tokenResponse.TokenType
        ));
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Error during token refresh");
        return Results.Problem(detail: "Internal server error", statusCode: 500);
    }
})
.RequireRateLimiting("auth");

app.Run();

// Request/Response Records (camelCase for iOS compatibility)
record TokenRequest(
    [property: System.Text.Json.Serialization.JsonPropertyName("code")] string Code,
    [property: System.Text.Json.Serialization.JsonPropertyName("redirectUri")] string RedirectUri
);

record RefreshRequest(
    [property: System.Text.Json.Serialization.JsonPropertyName("refreshToken")] string RefreshToken
);

record TokenResponse(
    [property: System.Text.Json.Serialization.JsonPropertyName("accessToken")] string AccessToken,
    [property: System.Text.Json.Serialization.JsonPropertyName("refreshToken")] string RefreshToken,
    [property: System.Text.Json.Serialization.JsonPropertyName("expiresIn")] int ExpiresIn,
    [property: System.Text.Json.Serialization.JsonPropertyName("tokenType")] string TokenType
);

// Harvest API response (snake_case from their API)
record HarvestTokenResponse(
    [property: System.Text.Json.Serialization.JsonPropertyName("access_token")] string AccessToken,
    [property: System.Text.Json.Serialization.JsonPropertyName("refresh_token")] string RefreshToken,
    [property: System.Text.Json.Serialization.JsonPropertyName("expires_in")] int ExpiresIn,
    [property: System.Text.Json.Serialization.JsonPropertyName("token_type")] string TokenType
);
