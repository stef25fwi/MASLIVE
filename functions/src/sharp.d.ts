declare module 'sharp' {
  export interface Metadata {
    width?: number;
    height?: number;
    format?: string;
    [key: string]: any;
  }

  export interface Sharp {
    metadata(): Promise<Metadata>;
    resize(
      width?: number,
      height?: number,
      options?: any,
    ): Sharp;
    jpeg(options?: any): Sharp;
    toFile(path: string): Promise<any>;
  }

  function sharp(input?: any): Sharp;
  export = sharp;
}
