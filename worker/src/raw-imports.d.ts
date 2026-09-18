/**
 * Vite (and so vitest) can import any file as a string with `?raw`. Used by
 * the config tests to read wrangler.toml without pulling Node's fs types into
 * a Workers-typed project.
 */
declare module '*?raw' {
  const content: string;
  export default content;
}
