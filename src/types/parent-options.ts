export type ParentOptions = {
  /**
   * It includes the prefix, the namespace separator :, and queue name.
   * @see {@link https://www.gnu.org/software/gawk/manual/html_node/Qualified-Names.html}
   */
  queue: string;
} & (
  | {
      /**
       * Parent identifier.
       */
      id: string;
      chainId?: never; // Explicitly disallow chainId when id is present
    }
  | {
      /**
       * Chain identifier.
       */
      chanId: string;
      id?: never; // Explicitly disallow id when chainId is present
    }
);
