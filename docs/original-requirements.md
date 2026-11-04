# Social Network for Creator Content

> Original project requirements, translated from Spanish. Kept as reference; the implementation scope is reduced (see the 8-day plan).

**Problem:** Content creators struggle to monetize their work due to low visibility and reach on saturated platforms.

**Solution:** I built a social network that optimizes creators' content to maximize engagement, increasing monetization by $300K per month using Rust, Node.js, and AWS S3.

**Impact:** Increased engagement by 2M monthly interactions and monetization by $300K per month.

**Technologies:** Rust, Node.js, AWS S3, API Gateway, pgvector

**New technologies to learn:** Rust, AWS S3, pgvector


## Phased plan

1. Phase 1: Platform architecture design and recommendation logic
2. Phase 2: Backend implementation with Node.js and Rust services
3. Phase 3: AWS S3 storage implementation and data optimization with pgvector
4. Phase 4: Production deployment, usability testing, and engagement measurement

## Overview

This project consists of building a social network aimed at content creators. The idea is to provide a platform that optimizes content visibility and engagement, allowing creators to increase the monetization of their work. Using technologies such as Rust for the backend, Node.js for microservices, and AWS S3 for content storage, the project aims to handle large volumes of data efficiently.

Rust offers exceptional performance and concurrency safety, which is crucial for handling the recommendation logic and processing large amounts of user data. AWS S3 is used to store multimedia content in a scalable and cost-effective way, while API Gateway provides a secure, managed access layer for the system's APIs. Integrating pgvector makes it possible to store and query feature vectors to improve content recommendations.

The project teaches key concepts of safe, concurrent programming in Rust, microservice design with Node.js, and cloud application architecture on AWS. It also provides hands-on experience using pgvector for AI and recommendations, a critical area in modern recommender systems.

## Architecture

```plaintext
+-----------------+      +-------------+        +----------------+      +------------+
|  User Interface | ---> |  API Gateway| -----> |  Recommendation | ---> | AWS S3     |
|  (React.js)     |      |  (Node.js)  |        |  Engine (Rust)  |      | (Storage)  |
+-----------------+      +-------------+        +----------------+      +------------+
                                        |                                  |        
                                        |                                  |
                                        v                                  v
                                   +----------------+             +---------------+
                                   |  pgvector DB   |             |  Analytics    |
                                   |  (PostgreSQL)  |             |  Engine       |
                                   +----------------+             +---------------+
```
- **User Interface**: Presents the application to users, allowing them to interact with content.
- **API Gateway**: Manages and secures API requests, routing them to the appropriate microservice.
- **Recommendation Engine (Rust)**: Processes user data and generates content recommendations.
- **AWS S3**: Stores creators' content, such as images and videos.
- **pgvector DB**: Stores content feature vectors to improve recommendations.
- **Analytics Engine**: Processes data to provide insights into engagement and monetization.

## Local environment (cloud simulation)

### Local environment setup

1. **Emulate AWS services with LocalStack**:
   - Emulated services: S3, API Gateway, Lambda
   - Startup command:
     ```bash
     docker-compose up
     ```

2. **Deploy infrastructure to LocalStack**:
   - Use Terraform with local endpoints:
     ```bash
     tflocal apply
     ```

3. **Point the application to the local endpoints**:
   - Environment variables:
     ```bash
     export AWS_ENDPOINT_URL=http://localhost:4566
     ```

4. **Verify that the services are running**:
   - List S3 buckets:
     ```bash
     awslocal s3 ls
     ```
   - Query API Gateway:
     ```bash
     curl http://localhost:4566/restapis/
     ```

## Cloud deployment

### Deploying to AWS

1. **Required changes**:
   - Update AWS credentials in `~/.aws/credentials`.
   - Change the Terraform endpoint to the desired region.

2. **Steps and commands**:
   - Run Terraform to deploy to AWS:
     ```bash
     terraform apply
     ```

3. **Production readiness checklist**:
   - Verify that the S3 buckets are configured correctly.
   - Test the Lambda functions with test events.
   - Confirm that API Gateway responds correctly to requests.

## Load testing

### Load testing with k6

1. **Tool**: k6
2. **Load scenario**:
   - Ramp-up from 0 to 2000 concurrent users over 5 minutes.
   - Hold 2000 concurrent users for 10 minutes.

3. **Execution**:
   ```bash
   k6 run loadtest/k6.js
   ```

4. **Observing results**:
   - Use Prometheus and Grafana to visualize performance metrics.
   - Configure k6 to export metrics to Prometheus and visualize them in Grafana dashboards.

## Target metrics

| Metric | Target | How to measure |
| --- | --- | --- |
| Target QPS / RPS | 2,000 sustained req/s | Measured with k6 during load tests, exporting metrics to Prometheus. |
| p50 / p95 / p99 latency | p99 < 200ms | Measured with k6 and visualized in Grafana. |
| Error rate | < 0.1% | Measured with k6, checking the percentage of failed requests. |
| Saturation point | Degradation starting at ~3,500 req/s | Identified during k6 load tests by watching for rising latency and error rate. |

## Tests (unit / integration)

### Unit and integration tests

1. **Unit tests in Rust**:
   ```rust
   #[cfg(test)]
   mod tests {
       use super::*;

       #[test]
       fn test_recommend_content() {
           let recommendations = recommend_content(1);
           assert!(recommendations.len() > 0);
       }
   }
   ```

2. **API integration tests**:
   - Use Mocha and Chai for Node.js:
   ```javascript
   const chai = require('chai');
   const chaiHttp = require('chai-http');
   const server = require('../app');
   chai.use(chaiHttp);

   describe('GET /recommendations/:userId', () => {
       it('should return an array of recommendations', (done) => {
           chai.request(server)
               .get('/recommendations/1')
               .end((err, res) => {
                   chai.expect(res).to.have.status(200);
                   chai.expect(res.body).to.be.an('array');
                   done();
               });
       });
   });
   ```

## Technical challenges

### Recommendation engine scalability

**Why it's hard:** Handling large volumes of data and generating real-time recommendations are significant challenges.

**How it's solved:** Using Rust for its high performance and concurrency safety, together with pgvector for efficient handling of feature vectors.

### Content storage and retrieval

**Why it's hard:** Managing large amounts of multimedia content requires a scalable, efficient storage system.

**How it's solved:** Using AWS S3 for object storage, which allows storage to scale horizontally without affecting performance.

### Latency optimization in API Gateway

**Why it's hard:** Latency can be a critical issue in real-time applications such as social networks.

**How it's solved:** Configuring caches and timeouts in API Gateway correctly, and optimizing Lambda functions for fast responses.


## Takeaways

- Implemented a recommendation engine in Rust using pgvector to improve user engagement.
- Developed and deployed Node.js microservices using AWS Lambda and API Gateway.
- Used AWS S3 to manage multimedia content storage at scale.
- Set up a local environment with LocalStack to emulate AWS services and ease development and testing.
- Ran k6 load tests to ensure the application's scalability and performance.
- Deployed the infrastructure on AWS with Terraform, ensuring consistent, automated deployments.

## Learning path

### Rust

Rust is a systems language that offers excellent performance and safety, ideal for highly concurrent applications.

### Rust learning path

1. **Introduction to Rust**
   - Understand the ownership and borrowing model.
   - Complete basic concurrent programming exercises.

2. **Building applications in Rust**
   - Implement the recommendation engine in Rust.
   - Optimize performance using advanced language features.

3. **Integration with AWS Lambda**
   - Deploy Lambda functions written in Rust.
   - Manage dependencies and optimize cold-start times.

4. **Resources**:
   - [The Rust Programming Language](https://doc.rust-lang.org/book/)
   - [Rust by Example](https://doc.rust-lang.org/rust-by-example/)
   - [Rustlings: hands-on exercises](https://github.com/rust-lang/rustlings)

### AWS S3

AWS S3 is a highly scalable, durable object storage service, essential for handling large amounts of multimedia content.

### AWS S3 learning path

1. **S3 basics**
   - Create and manage S3 buckets.
   - Configure access and security policies.

2. **Integration with applications**
   - Implement object storage and retrieval in the Node.js application.
   - Optimize S3 usage to reduce costs.

3. **Resources**:
   - [AWS S3 Developer Guide](https://docs.aws.amazon.com/AmazonS3/latest/dev/Welcome.html)
   - [AWS SDK for JavaScript](https://docs.aws.amazon.com/sdk-for-javascript/)

### pgvector

pgvector is a PostgreSQL extension that makes it easy to work with vectors for AI tasks, which is crucial for recommender systems.

### pgvector learning path

1. **Installation and configuration**
   - Install the pgvector extension in PostgreSQL.
   - Configure the environment for working with vectors.

2. **Usage in applications**
   - Store and query feature vectors from Rust.
   - Implement recommendation logic based on vector similarity.

3. **Resources**:
   - [pgvector GitHub Repository](https://github.com/pgvector/pgvector)
   - [PostgreSQL Documentation](https://www.postgresql.org/docs/)
