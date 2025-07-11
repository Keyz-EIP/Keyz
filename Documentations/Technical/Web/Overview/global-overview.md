# Global overview of the Web Application

For detailed setup and installation instructions, please refer to our [Getting Started Guide](./getting-started.md).

## Technologies used

This web application is built with [React](https://react.dev/), using [TypeScript](https://www.typescriptlang.org/) to ensure static typing and improve code robustness. The project leverages [Vite](https://vitejs.dev/) as its bundling tool for faster development and optimized production builds.

To ensure high code quality, ESLint is configured with the Airbnb style guide to enforce best practices. Additionally, Husky is integrated to manage Git hooks, including a pre-commit that runs lint-staged. This ensures that ESLint only checks staged files, improving performance during commits. Prettier is also set up to work alongside ESLint, ensuring consistent code formatting across the entire project.

### Stack and Tools

- React version: 18
- TypeScript version: ^5.5.4
- Vite version: ^5.4.7

### Code Quality

- ESLint version: 8.57.1
- Husky version: 4.3.8
- Lint-Staged version: 15.2.10

---

## Setup

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm run test

# Build for production
npm run build
```

---

## Testing

### Unit Testing

In this project, we use [Jest](https://jestjs.io/) as our primary testing framework for unit testing. Jest provides a robust environment for testing JavaScript and TypeScript code, making it an ideal choice for ensuring the reliability of our React application. We have integrated TypeScript into our testing workflow, allowing us to leverage type safety and autocompletion during test development. Our test files, typically named with the .test.tsx extension, are placed alongside the components they test, ensuring a modular and maintainable codebase.

### Functional Testing

In our project, we employ [Jest](https://jestjs.io/) for functional testing to validate the overall behavior of our application. Jest's powerful testing capabilities enable us to simulate user interactions and verify that our application functions as intended across various scenarios. By utilizing TypeScript for our functional tests, we benefit from enhanced type safety, reducing potential errors and improving code quality. Our functional test files, typically suffixed with .test.tsx, are organized alongside the relevant components, promoting a clear and cohesive testing structure that aligns with our development practices.

# Testing Commands

The project includes several testing commands that can be run using npm:

## Basic Test Run

```bash
npm run test
```

Runs all tests once

## Watch Mode

```bash
npm run test:watch
```

Runs tests in watch mode - tests will re-run when files change

## Coverage Report

```bash
npm run test:coverage
```

Runs tests and generates a coverage report showing:

- Line coverage
- Function coverage
- Branch coverage
- Statement coverage

## Test Files Location

Tests should be placed in `__tests__` folders next to the files they test:

```
src/
  components/
    Button/
      Button.tsx
      __tests__/
        Button.test.tsx
```
