using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;

namespace AzureFunctionsConfiguration
{
    internal class Program
    {
        static void Main(string[] args)
        {
            FunctionsDebugger.Enable();

            var host = new HostBuilder()
                .ConfigureAppConfiguration((hostContext, configBuilder) =>
                {
                    configBuilder.AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);

                    // Add Azure Key Vault as a configuration provider
                    var configuration = configBuilder.Build();
                    var keyVaultEndpoint = "https://po-vault-dev.vault.azure.net";
                    if (!string.IsNullOrEmpty(keyVaultEndpoint))
                    {
                        configBuilder.AddAzureKeyVault(new Uri(keyVaultEndpoint), new DefaultAzureCredential());
                    }
                })
                .ConfigureFunctionsWorkerDefaults()
                .ConfigureServices((hostContext, services) =>
                {
                    services.AddOptions<AzureFunctionsConfigurationOptions>().Configure<IConfiguration>((options, configuration) =>
                    {
                        configuration.GetSection("AzureFunctionsConfiguration").Bind(options);
                    });
                })
                .Build();

            host.Run();
        }
    }

  
}
