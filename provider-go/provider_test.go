package main

import (
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/pact-foundation/pact-go/v2/models"
	"github.com/pact-foundation/pact-go/v2/provider"
)

func noSetup(bool, models.ProviderState) (models.ProviderStateResponse, error) {
	return nil, nil
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func pactSource(t *testing.T, request *provider.VerifyRequest) {
	brokerURL := os.Getenv("PACT_BROKER_URL")
	if brokerURL == "" {
		pactDir, err := filepath.Abs("../pacts")
		if err != nil {
			t.Fatal(err)
		}
		request.PactDirs = []string{pactDir}
		return
	}

	wipSince, err := time.Parse("2006-01-02", envOr("WIP_PACTS_SINCE", "2020-01-01"))
	if err != nil {
		t.Fatal(err)
	}

	request.BrokerURL = brokerURL
	request.BrokerUsername = envOr("PACT_BROKER_USERNAME", "pact")
	request.BrokerPassword = envOr("PACT_BROKER_PASSWORD", "pact")
	request.ProviderVersion = envOr("VERSION", "0.0.0-local")
	request.ProviderBranch = envOr("BRANCH", "main")
	request.PublishVerificationResults = os.Getenv("PUBLISH_RESULTS") != "false"
	request.EnablePending = true
	request.IncludeWIPPactsSince = &wipSince
	request.ConsumerVersionSelectors = []provider.Selector{
		&provider.ConsumerVersionSelector{MainBranch: true},
		&provider.ConsumerVersionSelector{DeployedOrReleased: true},
		&provider.ConsumerVersionSelector{MatchingBranch: true},
	}
}

func TestProviderVerification(t *testing.T) {
	server := httptest.NewServer(newMux())
	defer server.Close()

	request := provider.VerifyRequest{
		ProviderBaseURL: server.URL,
		Provider:        "product-service",
		StateHandlers: models.StateHandlers{
			"product 1 exists":          noSetup,
			"product 99 does not exist": noSetup,
		},
	}
	pactSource(t, &request)

	if err := provider.NewVerifier().VerifyProvider(t, request); err != nil {
		t.Fatal(err)
	}
}
