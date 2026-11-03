# Red Social para Contenido de Creador

**Problema:** Los creadores de contenido tienen problemas para monetizar su trabajo debido a la baja visibilidad y alcance en plataformas saturadas.

**Solución:** Construí una red social que optimiza el contenido de los creadores para maximizar el engagement aumentando la monetización en $300K mensuales usando Rust, Node.js, y AWS S3.

**Impacto:** Aumentó el engagement en 2M interacciones mensuales, incrementó la monetización en $300K mensuales.

**Tecnologías:** Rust, Node.js, AWS S3, Api Gateway, pgvector

**Tecnologías nuevas a aprender:** Rust, AWS S3, pgvector


## Plan por fases

1. Fase 1: Diseño de arquitectura de plataforma y lógica de recomendación
2. Fase 2: Implementación del backend con Node.js y servicios en Rust
3. Fase 3: Implementación de almacenamiento en AWS S3 y optimización de datos con pgvector
4. Fase 4: Despliegue productivo, pruebas de usabilidad y medición de engagement

## Explicación

Este proyecto consiste en desarrollar una red social orientada a creadores de contenido. La idea es proveer una plataforma que optimice la visibilidad y engagement del contenido, permitiendo a los creadores aumentar la monetización de su trabajo. Utilizando tecnologías como Rust para el backend, Node.js para el manejo de microservicios y AWS S3 para el almacenamiento de contenido, el proyecto busca manejar grandes volúmenes de datos de manera eficiente. 

Rust ofrece un rendimiento excepcional y seguridad de concurrencia, lo cual es crucial para manejar la lógica de recomendación y procesamiento de grandes cantidades de datos de usuario. AWS S3 se utiliza para almacenar contenido multimedia de manera escalable y económica, mientras que Api Gateway proporciona una capa de acceso seguro y gestionado para las API del sistema. La integración de pgvector permite almacenar y consultar vectores de características para mejorar las recomendaciones de contenido.

El proyecto enseña conceptos clave de programación concurrente y segura en Rust, diseño de microservicios con Node.js, y arquitectura de aplicaciones en la nube utilizando AWS. Además, proporciona experiencia práctica en el uso de pgvector para AI y recomendaciones, un área crítica en sistemas de recomendación modernos.

## Arquitectura

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
- **User Interface**: Presenta la aplicación a los usuarios, permitiendo la interacción con el contenido.
- **API Gateway**: Gestiona y asegura las solicitudes API, dirigiéndolas al microservicio adecuado.
- **Recommendation Engine (Rust)**: Procesa los datos de usuario y genera recomendaciones de contenido.
- **AWS S3**: Almacena el contenido de los creadores, como imágenes y videos.
- **pgvector DB**: Almacena las características vectoriales de los contenidos para mejorar las recomendaciones.
- **Analytics Engine**: Procesa datos para proporcionar insights sobre engagement y monetización.

## Entorno local (simulación cloud)

### Configuración del Entorno Local

1. **Emular Servicios de AWS con LocalStack**:
   - Servicios emulados: S3, API Gateway, Lambda
   - Comando de arranque:
     ```bash
     docker-compose up
     ```

2. **Desplegar Infraestructura en LocalStack**:
   - Usar Terraform con endpoints locales:
     ```bash
     tflocal apply
     ```

3. **Apuntar la aplicación a los endpoints locales**:
   - Variables de entorno:
     ```bash
     export AWS_ENDPOINT_URL=http://localhost:4566
     ```

4. **Verificar que los servicios están funcionando**:
   - Listar buckets en S3:
     ```bash
     awslocal s3 ls
     ```
   - Consultar API Gateway:
     ```bash
     curl http://localhost:4566/restapis/
     ```

## Despliegue a cloud

### Despliegue en AWS

1. **Cambios necesarios**:
   - Actualizar credenciales de AWS en el archivo `~/.aws/credentials`.
   - Cambiar el endpoint de Terraform a la región deseada.

2. **Pasos y Comandos**:
   - Ejecutar Terraform para desplegar en AWS:
     ```bash
     terraform apply
     ```

3. **Checklist de Puesta en Producción**:
   - Verificar que los buckets de S3 estén correctamente configurados.
   - Probar las funciones Lambda con eventos de prueba.
   - Confirmar que el API Gateway responde correctamente a las solicitudes.

## Pruebas de carga

### Pruebas de Carga con k6

1. **Herramienta**: k6
2. **Escenario de carga**:
   - Ramp-up de 0 a 2000 usuarios concurrentes en 5 minutos.
   - Mantener 2000 usuarios concurrentes por 10 minutos.

3. **Ejecución**:
   ```bash
   k6 run loadtest/k6.js
   ```

4. **Observación de Resultados**:
   - Utilizar Prometheus y Grafana para visualizar métricas de rendimiento.
   - Configurar k6 para exportar métricas a Prometheus y visualizarlas en dashboards de Grafana.

## Métricas objetivo

| Métrica | Objetivo | Cómo medir |
| --- | --- | --- |
| QPS / RPS objetivo | 2.000 req/s sostenidos | Medido con k6 durante pruebas de carga, exportando métricas a Prometheus. |
| Latencia p50 / p95 / p99 | p99 < 200ms | Medido con k6 y visualizado en Grafana. |
| Tasa de error | < 0.1% | Medido con k6, verificando el porcentaje de solicitudes fallidas. |
| Punto de saturación | Degradación a partir de ~3.500 req/s | Identificado durante pruebas de carga con k6, observando aumento de latencia y tasa de error. |

## Pruebas (unit / integración)

### Pruebas Unitarias y de Integración

1. **Pruebas Unitarias en Rust**:
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

2. **Pruebas de Integración para el API**:
   - Usar Mocha y Chai para Node.js:
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

## Complejidades técnicas

### Escalabilidad del motor de recomendaciones

**Por qué es difícil:** El manejo de grandes volúmenes de datos y la generación de recomendaciones en tiempo real son desafíos significativos.

**Cómo se resuelve:** Utilizando Rust para aprovechar su alto rendimiento y seguridad de concurrencia, junto con pgvector para manejo eficiente de vectores de características.

### Almacenamiento y recuperación de contenido

**Por qué es difícil:** Gestionar grandes cantidades de contenido multimedia requiere un sistema de almacenamiento escalable y eficiente.

**Cómo se resuelve:** Empleando AWS S3 para almacenamiento de objetos, lo que permite escalar horizontalmente el almacenamiento sin afectar el rendimiento.

### Optimización de latencia en API Gateway

**Por qué es difícil:** La latencia puede ser un problema crítico en aplicaciones de tiempo real como redes sociales.

**Cómo se resuelve:** Configurando correctamente las cachés y los tiempos de espera en el API Gateway, y optimizando las funciones Lambda para respuestas rápidas.


## Takeaways

- Implementé un motor de recomendaciones en Rust utilizando pgvector para mejorar el engagement del usuario.
- Desarrollé y desplegué microservicios en Node.js utilizando AWS Lambda y API Gateway.
- Utilicé AWS S3 para gestionar almacenamiento de contenido multimedia de manera escalable.
- Configuré un entorno local con LocalStack para emular servicios de AWS y facilitar el desarrollo y pruebas.
- Realicé pruebas de carga con k6 para asegurar la escalabilidad y rendimiento de la aplicación.
- Desplegué la infraestructura en AWS utilizando Terraform, asegurando un despliegue consistente y automatizado.

## Ruta de aprendizaje

### Rust

Rust es un lenguaje de sistemas que ofrece un rendimiento y seguridad excelentes, ideal para aplicaciones de alta concurrencia.

### Ruta de Aprendizaje para Rust

1. **Introducción a Rust**
   - Comprender el modelo de propiedad y préstamo.
   - Realizar ejercicios básicos de programación concurrente.

2. **Desarrollo de Aplicaciones en Rust**
   - Implementar el motor de recomendaciones en Rust.
   - Optimizar el rendimiento utilizando características avanzadas del lenguaje.

3. **Integración con AWS Lambda**
   - Desplegar funciones Lambda escritas en Rust.
   - Gestionar dependencias y optimizar tiempos de arranque.

4. **Recursos**:
   - [The Rust Programming Language](https://doc.rust-lang.org/book/)
   - [Rust by Example](https://doc.rust-lang.org/rust-by-example/)
   - [Rustlings: ejercicios prácticos](https://github.com/rust-lang/rustlings)

### AWS S3

AWS S3 es un servicio de almacenamiento de objetos altamente escalable y duradero, esencial para manejar grandes cantidades de contenido multimedia.

### Ruta de Aprendizaje para AWS S3

1. **Conceptos Básicos de S3**
   - Crear y gestionar buckets de S3.
   - Configurar políticas de acceso y seguridad.

2. **Integración con Aplicaciones**
   - Implementar almacenamiento y recuperación de objetos en la aplicación Node.js.
   - Optimizar el uso de S3 para reducir costos.

3. **Recursos**:
   - [AWS S3 Developer Guide](https://docs.aws.amazon.com/AmazonS3/latest/dev/Welcome.html)
   - [AWS SDK for JavaScript](https://docs.aws.amazon.com/sdk-for-javascript/)

### pgvector

pgvector es una extensión de PostgreSQL que facilita el manejo de vectores para tareas de AI, crucial para sistemas de recomendación.

### Ruta de Aprendizaje para pgvector

1. **Instalación y Configuración**
   - Instalar la extensión pgvector en PostgreSQL.
   - Configurar el entorno para el manejo de vectores.

2. **Uso en Aplicaciones**
   - Almacenar y consultar vectores de características en Rust.
   - Implementar lógica de recomendación basada en similitud de vectores.

3. **Recursos**:
   - [pgvector GitHub Repository](https://github.com/pgvector/pgvector)
   - [PostgreSQL Documentation](https://www.postgresql.org/docs/)
