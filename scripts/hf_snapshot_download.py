from huggingface_hub import snapshot_download

print('starting snapshot_download')
snapshot_download(
    repo_id='facebook/m2m100_418M',
    cache_dir='./.hf_cache',
    allow_patterns=[
        'pytorch_model.bin',
        'sentencepiece.bpe.model',
        'vocab.json',
        'tokenizer_config.json',
        'config.json',
        'special_tokens_map.json',
        'tokenizer.json',
    ],
)
print('snapshot_download finished')
