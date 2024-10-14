export type ChangeEventPayload = {
  value: string;
};

export type MyModuleEvents = {
  onChange: (params: ChangeEventPayload) => void;
};

export type MyModuleViewProps = {
  name: string;
};
