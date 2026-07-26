using Microsoft.AspNetCore.Mvc;

namespace YoutubeLiveApp.Controllers;

[ApiController]
[Route("api/youtube")]
public class YouTubeController : ControllerBase
{
    private readonly ILogger<YouTubeController> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public YouTubeController(
        ILogger<YouTubeController> logger,
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string q)
    {
        if (string.IsNullOrWhiteSpace(q))
        {
            return BadRequest(new { error = "Query parameter 'q' is required" });
        }

        try
        {
            var apiKey = _configuration["YouTubeApiKey"] ?? Environment.GetEnvironmentVariable("YOUTUBE_API_KEY");
            
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                _logger.LogWarning("YouTube API Key not configured");
                return StatusCode(500, new { error = "YouTube API Key not configured" });
            }

            var httpClient = _httpClientFactory.CreateClient();
            var url = $"https://www.googleapis.com/youtube/v3/search?part=snippet&q={Uri.EscapeDataString(q)}&type=video&maxResults=12&key={apiKey}";

            var response = await httpClient.GetAsync(url);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("YouTube API returned status code {StatusCode}", response.StatusCode);
                var errorContent = await response.Content.ReadAsStringAsync();
                _logger.LogError("Error response: {ErrorContent}", errorContent);
                return StatusCode((int)response.StatusCode, new { error = "Failed to fetch from YouTube API" });
            }

            var content = await response.Content.ReadAsStringAsync();
            var data = System.Text.Json.JsonSerializer.Deserialize<YouTubeSearchResponse>(content);

            if (data?.Items == null)
            {
                return Ok(new { items = new List<object>() });
            }

            var videos = data.Items.Select(item => new
            {
                id = item.Id?.VideoId ?? "",
                title = item.Snippet?.Title ?? "",
                description = item.Snippet?.Description ?? "",
                thumbnail = item.Snippet?.Thumbnails?.Medium?.Url ?? item.Snippet?.Thumbnails?.Default?.Url ?? "",
                channelTitle = item.Snippet?.ChannelTitle ?? "",
                publishedAt = item.Snippet?.PublishedAt ?? ""
            }).ToList();

            return Ok(new { items = videos });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching YouTube videos");
            return StatusCode(500, new { error = "Internal server error" });
        }
    }
}

// DTOs for YouTube API response
public class YouTubeSearchResponse
{
    public List<YouTubeSearchItem>? Items { get; set; }
}

public class YouTubeSearchItem
{
    public YouTubeId? Id { get; set; }
    public YouTubeSnippet? Snippet { get; set; }
}

public class YouTubeId
{
    public string? VideoId { get; set; }
}

public class YouTubeSnippet
{
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? ChannelTitle { get; set; }
    public string? PublishedAt { get; set; }
    public YouTubeThumbnails? Thumbnails { get; set; }
}

public class YouTubeThumbnails
{
    public YouTubeThumbnail? Default { get; set; }
    public YouTubeThumbnail? Medium { get; set; }
    public YouTubeThumbnail? High { get; set; }
}

public class YouTubeThumbnail
{
    public string? Url { get; set; }
}
