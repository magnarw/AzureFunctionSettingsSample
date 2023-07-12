using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AzureFunctionsConfiguration
{
    public class TestFunction
    {
        private readonly ILogger _logger;

        private AzureFunctionsConfigurationOptions _options;

        public TestFunction(ILoggerFactory loggerFactory, IOptions<AzureFunctionsConfigurationOptions> options)
        {
            _logger = loggerFactory.CreateLogger<TestFunction>();
            _options = options.Value;
        }

        [Function("Function1")]
        public HttpResponseData Run([HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");

            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "text/plain; charset=utf-8");

            response.WriteString($"Hello app settings! DummySecret: {_options.DummySecretName}, DummyNoneSecretName:{_options.DummyNotSecretName}");

            return response;
        }
    }
}
