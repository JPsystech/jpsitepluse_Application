enum Environment { dev, staging, prod }

class EnvironmentConfig {
  static Environment current = Environment.dev;
}
