import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  experimental: {
    reactCompiler: true,
    optimizePackageImports: ['@xyflow/react', 'lucide-react'],
  },
};

export default nextConfig;
