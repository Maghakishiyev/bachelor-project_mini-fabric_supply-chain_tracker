/** @type {import('next').NextConfig} */
const nextConfig = {
    /* config options here */
    reactStrictMode: true,
    output: 'standalone',
    experimental: {
        serverComponentsExternalPackages: [
            '@hyperledger/fabric-gateway',
            '@grpc/grpc-js',
            'pkcs11js',
            'crypto'
        ]
    },
    // Fix for native binary modules
    webpack: (config, { isServer }) => {
        // Exclude modules with native dependencies from client-side bundling
        if (!isServer) {
            config.resolve.fallback = {
                ...config.resolve.fallback,
                net: false,
                tls: false,
                fs: false,
                path: false,
                os: false,
                crypto: false,
                'fs/promises': false,
                '@grpc/grpc-js': false,
                'pkcs11js': false
            };
        }
        
        // Exclude binary modules from webpack processing
        config.module.noParse = [
            /pkcs11\.node/,
            /node_modules\/pkcs11js\/build\/Release\/.*/
        ];
        
        return config;
    },
};

export default nextConfig;