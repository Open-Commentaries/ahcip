export type Author = {
    email: string;
    name: string;
    username: string;
}

export type Card = {
    n: string;
    next_n: string;
    xml_content: string;
}

export type Tag = {
    description: string;
    name: string;
    image: string;
}

export type Comment = {
    authors: Author[];
    citable_urn: string;
    citation: string;
    isHighlighted?: boolean;
    target_urn: string;
    tags: Tag[];
    title: string;
    text: string;
}

export type Line = {
    n: string;
}