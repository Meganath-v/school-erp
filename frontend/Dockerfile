# Production Dockerfile for Flutter Web with Nginx
FROM nginx:alpine

# Copy compiled Flutter web assets
COPY build/web /usr/share/nginx/html

# Copy Nginx SPA configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
