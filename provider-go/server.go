package main

import (
	"encoding/json"
	"net/http"
)

type Product struct {
	ID    string  `json:"id"`
	Name  string  `json:"name"`
	Price float64 `json:"price"`
}

var products = map[string]Product{
	"1": {ID: "1", Name: "Laptop", Price: 999.99},
}

func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /products/{id}", getProduct)
	return mux
}

func getProduct(w http.ResponseWriter, r *http.Request) {
	product, ok := products[r.PathValue("id")]
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(product)
}
