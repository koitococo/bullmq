export type QualifiedQueueOption = {
  /**
   * It includes the prefix, the namespace separator :, and queue name.
   * @see {@link https://www.gnu.org/software/gawk/manual/html_node/Qualified-Names.html}
   */
  queue: string;
};

export type BaseParentOptions = QualifiedQueueOption & {
  /**
   * Parent identifier.
   */
  id: string;
};

export type ParentOptions = QualifiedQueueOption &
  (
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
        chainId: string;
        id?: never; // Explicitly disallow id when chainId is present
      }
  );
