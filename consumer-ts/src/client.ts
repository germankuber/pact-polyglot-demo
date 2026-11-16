export interface Product {
  id: string;
  name: string;
  price: number;
}

export async function getProduct(baseUrl: string, id: string): Promise<Product | null> {
  const response = await fetch(`${baseUrl}/products/${id}`);
  if (response.status === 404) {
    return null;
  }
  if (!response.ok) {
    throw new Error(`Unexpected status ${response.status}`);
  }
  return (await response.json()) as Product;
}
