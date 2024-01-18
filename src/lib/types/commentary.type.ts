export type Author = {
    email: string;
    name: string;
    username: string;
}

export type Tag = {
    description: string;
    name: string;
    image: string;
}

export type Comment = {
    authors: Author[];
    body: string;
    target_urn: string;
    tags: Tag[];
    title: string;
}

export type Line = {
    n: string;
}