/** Constant-time Buffer comparison utility. */
declare function bufferEqual(a: Buffer, b: Buffer): boolean;

declare namespace bufferEqual {
    /** Patch `Buffer.prototype.equal` to use the constant-time version. */
    function install(): void;

    /** Restore the original `Buffer.prototype.equal`. */
    function restore(): void;
}

export = bufferEqual;
